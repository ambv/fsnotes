//
//  EditTextView.swift
//  FSNotes
//
//  Created by Oleksandr Glushchenko on 8/11/17.
//  Copyright © 2017 Oleksandr Glushchenko. All rights reserved.
//

import Cocoa
import Down
import Highlightr
import Marklight

class EditTextView: NSTextView {
    var note: Note?
    
    class UndoInfo: NSObject {
        let text: String
        let replacementRange: NSRange
        
        init(text: String, replacementRange: NSRange) {
            self.text = text
            self.replacementRange = replacementRange
        }
    }
    
    var downView: MarkdownView?
    let highlightColor = NSColor(red:1.00, green:0.90, blue:0.70, alpha:1.0)
        
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
    }

    override func mouseMoved(with event: NSEvent) {
        if UserDefaultsManagement.preview {
            return
        }
        
        super.mouseMoved(with: event)
    }
    
    @IBAction func editorMenuItem(_ sender: Any) {
        let keyEquivalent = (sender as AnyObject).keyEquivalent.lowercased()
        
        let dict = ["b": 11, "i": 34, "j": 38, "y": 16, "u": 32, "1": 18, "2": 19, "3": 20, "4": 21, "5": 23, "6": 22] as [String: UInt16]
        
        if (dict[keyEquivalent] != nil) {
            let keyCode = dict[keyEquivalent]!
            let modifier = (sender as AnyObject).keyEquivalentModifierMask.rawValue == 262144 ? 393475 : 0
            
            _ = formatShortcut(keyCode: keyCode, modifier: UInt(modifier))
        }
    }
    
    @IBAction func togglePreview(_ sender: Any) {
        let mainWindow = NSApplication.shared.windows.first
        let viewController = mainWindow?.contentViewController as! ViewController
        
        viewController.togglePreview()
    }
    
    override func mouseDown(with event: NSEvent) {
        let viewController = self.window?.contentViewController as! ViewController
        if (!viewController.emptyEditAreaImage.isHidden) {
            viewController.makeNote(NSTextField())
        }
        return super.mouseDown(with: event)
    }
    
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        /* Skip command-shift-b conflicted with cmd-b */
        if event.modifierFlags.contains(NSEvent.ModifierFlags.command) && event.modifierFlags.contains(NSEvent.ModifierFlags.shift) && event.keyCode == 11 {
            return super.performKeyEquivalent(with: event)
        }
        
        if (event.modifierFlags.contains(NSEvent.ModifierFlags.command) || event.modifierFlags.rawValue == 393475) {
            if (formatShortcut(keyCode: event.keyCode, modifier: event.modifierFlags.rawValue as UInt)) {
                return true
            }
        }
        
        return super.performKeyEquivalent(with: event)
    }
    
    func getSelectedNote() -> Note? {
        let mainWindow = NSApplication.shared.windows.first
        let viewController = mainWindow?.contentViewController as! ViewController
        let note = viewController.notesTableView.getNoteFromSelectedRow()
        return note
    }
        
    func fill(note: Note, highlight: Bool = false) {
        self.note = note
        
        subviews.removeAll()
        undoManager?.removeAllActions()
        
        isEditable = !UserDefaultsManagement.preview
        isRichText = note.isRTF()
        
        typingAttributes.removeAll()
        typingAttributes[.font] = UserDefaultsManagement.noteFont
        
        if (isRichText) {
            let attrString = createAttributedString(note: note)
            textStorage?.setAttributedString(attrString)
        } else {
            if (UserDefaultsManagement.preview) {
                let path = Bundle.main.path(forResource: "DownView", ofType: ".bundle")
                let url = NSURL.fileURL(withPath: path!)
                let bundle = Bundle(url: url)
                
                do {
                    downView = try? MarkdownView(frame: (self.superview?.bounds)!, markdownString: note.getPrettifiedContent(), templateBundle: bundle) {
                    }
                
                    addSubview(downView!)
                }
            } else {
                let storage = NotesTextStorage()
                layoutManager?.invalidateLayout(forCharacterRange: NSMakeRange(0, (textStorage?.length)!), actualCharacterRange: nil)
                layoutManager?.replaceTextStorage(storage)
                textStorage?.setAttributedString(note.content)
                
                if highlight {
                    //EditTextView.timer?.invalidate()
                    //EditTextView.timer = Timer.scheduledTimer(timeInterval: TimeInterval(0.5), target: self, selector: #selector(timerHighlight), userInfo: nil, repeats: false)
                }
            }
        }
        
        if highlight {
            highlightKeyword()
        }
        
        let viewController = self.window?.contentViewController as! ViewController
        viewController.emptyEditAreaImage.isHidden = true
    }
    
    private static var timer: Timer?
    
    func getAttributedString() -> NSMutableAttributedString? {
        guard let text = textStorage else {
            return nil
        }
        
        return NSMutableAttributedString(attributedString: text.attributedSubstring(from: NSRange(0..<text.length)))
    }
    
    @objc func timerHighlight() {
        higlightLinks()
        
        guard let content = getAttributedString() else {
            return
        }
        
        //highlightCode(initialFill: true, content: content)
    }
    
    var isHighlighted: Bool = false
    
    func removeHighlight() {
        guard isHighlighted else {
            return
        }
        
        isHighlighted = false
        
        // save cursor position
        let cursorLocation = selectedRanges[0].rangeValue.location
        
        highlightKeyword(remove: true)
        
        // restore cursor
        setSelectedRange(NSRange.init(location: cursorLocation, length: 0))
    }
    
    func highlightKeyword(remove: Bool = false) {
        if !remove {
            isHighlighted = true
        }
        
        let mainWindow = NSApplication.shared.windows.first
        let viewController = mainWindow?.contentViewController as! ViewController
        let search = viewController.search.stringValue
        
        guard search.count > 0 && !search.starts(with: "\\") else {
            return
        }
        
        let searchTerm = search
        let attributedString:NSMutableAttributedString = NSMutableAttributedString(attributedString: textStorage!)
        let pattern = "(\(searchTerm))"
        let range:NSRange = NSMakeRange(0, (textStorage?.string.count)!)
        let regex = try! NSRegularExpression(pattern: pattern, options: [NSRegularExpression.Options.caseInsensitive])
        
        regex.enumerateMatches(
            in: (textStorage?.string)!,
            options: NSRegularExpression.MatchingOptions(),
            range: range,
            using: {
                (textCheckingResult, matchingFlags, stop) -> Void in
                let subRange = textCheckingResult?.range
                
                if remove {
                    attributedString.removeAttribute(NSAttributedStringKey.backgroundColor, range: subRange!)
                } else {
                    attributedString.addAttribute(NSAttributedStringKey.backgroundColor, value: highlightColor, range: subRange!)
                }
            }
        )
        
        textStorage?.setAttributedString(attributedString)
    }
    
    func save(note: Note) -> Bool {
        let fileUrl = note.url
        let fileExtension = fileUrl?.pathExtension
        
        do {
            let range = NSRange(location: 0, length: (textStorage?.string.count)!)
            let documentAttributes = DocumentAttributes.getKey(fileExtension: fileExtension!)
            let text = try textStorage?.fileWrapper(from: range, documentAttributes: documentAttributes)
            try text?.write(to: fileUrl!, options: FileWrapper.WritingOptions.atomic, originalContentsURL: nil)
           
            return true
        } catch let error {
            NSLog(error.localizedDescription)
        }
        
        return false
    }
    
    func clear() {
        guard let manager = layoutManager else {
            return
        }
        
        manager.replaceTextStorage(NSTextStorage())
        subviews.removeAll()
        isEditable = false
        
        let viewController = self.window?.contentViewController as! ViewController
        viewController.emptyEditAreaImage.isHidden = false
    }
    
    func createAttributedString(note: Note) -> NSAttributedString {
        let url = note.url
        let fileExtension = url?.pathExtension
        var attributedString = NSAttributedString()
        
        do {
            let options = DocumentAttributes.getReadingOptionKey(fileExtension: fileExtension!)
            attributedString = try NSAttributedString(url: url!, options: options, documentAttributes: nil)
        } catch {
            attributedString = NSAttributedString(string: "", attributes: [.font: UserDefaultsManagement.noteFont])
        }
        
        return attributedString
    }
    
    func formatShortcut(keyCode: UInt16, modifier: UInt = 0) -> Bool {
        let mainWindow = NSApplication.shared.windows.first
        let viewController = mainWindow?.contentViewController as! ViewController
        let editArea = viewController.editArea!
        
        guard let currentNote = getSelectedNote() else {
            return false
        }
        
        if (!editArea.isEditable) {
            return false
        }

        let text = editArea.textStorage!.string as NSString
        let range = editArea.selectedRange()
        let selectedText = text.substring(with: range) as NSString
        let selectedRange = NSMakeRange(0, selectedText.length)
        
        let attributedSelected = editArea.attributedSubstring(forProposedRange: range, actualRange: nil)
        var attributedText = NSMutableAttributedString()
        
        if (attributedSelected == nil) {
            attributedText.addAttributes([.font: UserDefaultsManagement.noteFont], range: NSMakeRange(0, selectedText.length))
        } else {
            attributedText = NSMutableAttributedString(attributedString: attributedSelected!)
        }
        
        switch keyCode {
        case 11: // cmd-b
            if (!currentNote.isRTF()) {
                attributedText.mutableString.setString("**" + attributedText.string + "**")
            } else {
                if (selectedText.length > 0) {
                    let fontAttributes = attributedSelected?.fontAttributes(in: selectedRange)
                    let newFont = toggleBoldFont(font: fontAttributes![.font] as! NSFont)
                    attributedText.addAttribute(.font, value: newFont, range: selectedRange)
                }

                typingAttributes[.font] = toggleBoldFont(font: typingAttributes[.font] as! NSFont)
            }
            break
        case 34:
            // control-shift-i
            if (!currentNote.isRTF() && modifier == 393475) {
                attributedText.mutableString.setString("![](" + attributedText.string + ")")
                break
            }
        
            // cmd-i
            if (!currentNote.isRTF()) {
                attributedText.mutableString.setString("_" + attributedText.string + "_")
            } else {
                if (selectedText.length > 0) {
                    let fontAttributes = attributedSelected?.fontAttributes(in: selectedRange)
                    let newFont = toggleItalicFont(font: fontAttributes![.font] as! NSFont)
                    attributedText.addAttribute(.font, value: newFont, range: selectedRange)
                }
                
                typingAttributes[.font] = toggleItalicFont(font: typingAttributes[.font] as! NSFont)
            }
            break
        case 32: // cmd-u
            if (currentNote.isRTF()) {
                if (selectedText.length > 0) {
                    attributedText.removeAttribute(NSAttributedStringKey(rawValue: "NSUnderline"), range: NSMakeRange(0, selectedText.length))
                }
                
                if (typingAttributes[.underlineStyle] == nil) {
                    attributedText.addAttribute(NSAttributedStringKey.underlineStyle, value: NSUnderlineStyle.styleSingle.rawValue, range: NSMakeRange(0, selectedText.length))
                    typingAttributes[.underlineStyle] = 1
                } else {
                    typingAttributes.removeValue(forKey: NSAttributedStringKey(rawValue: "NSUnderline"))
                }
            }
            break
        case 16: // cmd-y
            if (currentNote.isRTF()) {
                if (selectedText.length > 0) {
                    attributedText.removeAttribute(NSAttributedStringKey(rawValue: "NSStrikethrough"), range: NSMakeRange(0, selectedText.length))
                }
                
                if (typingAttributes[.strikethroughStyle] == nil) {
                    attributedText.addAttribute(NSAttributedStringKey.strikethroughStyle, value: 2, range: NSMakeRange(0, selectedText.length))
                    typingAttributes[.strikethroughStyle] = 2
                } else {
                    typingAttributes.removeValue(forKey: NSAttributedStringKey(rawValue: "NSStrikethrough"))
                }
            } else {
                attributedText.mutableString.setString("~~" + attributedText.string + "~~")
            }
        case (18...23): // cmd-1/6 (headers 1/6)
            if (!currentNote.isRTF()) {
                var string = ""
                var offset = 2
                
                for index in [18,19,20,21,23,22] {
                    string = string + "#"
                    if Int(keyCode) == index {
                        break
                    }
                    offset = offset + 1
                }
                
                attributedText.mutableString.setString(string + " " + attributedText.string)
            }
            break
        case 38: // control-shift-j (link)
            if (!currentNote.isRTF() && modifier == 393475) {
                attributedText.mutableString.setString("[](" + attributedText.string + ")")
            }
            break
        default:
            return false
        }
        
        if (!UserDefaultsManagement.preview) {
            editArea.textStorage!.replaceCharacters(in: range, with: attributedText)
            
            if (currentNote.isRTF()) {
                editArea.setSelectedRange(range)
            }
        
            currentNote.save(editArea.textStorage!)
            return true
        }
        
        return false
    }
    
    func toggleBoldFont(font: NSFont) -> NSFont {
        var mask = 0
        
        if (font.isBold) {
            if (font.isItalic) {
                mask = NSFontItalicTrait
            }
        } else {
            if (font.isItalic) {
                mask = NSFontBoldTrait|NSFontItalicTrait
            } else {
                mask = NSFontBoldTrait
            }
        }
       
        return NSFontManager().font(withFamily: UserDefaultsManagement.noteFont.familyName!, traits: NSFontTraitMask(rawValue: NSFontTraitMask.RawValue(mask)), weight: 0, size: CGFloat(UserDefaultsManagement.fontSize))!
    }
    
    func toggleItalicFont(font: NSFont) -> NSFont {
        var mask = 0
        
        if (font.isItalic) {
            if (font.isBold) {
                mask = NSFontBoldTrait
            }
        } else {
            if (font.isBold) {
                mask = NSFontBoldTrait|NSFontItalicTrait
            } else {
                mask = NSFontItalicTrait
            }
        }
        
        return NSFontManager().font(withFamily: UserDefaultsManagement.noteFont.familyName!, traits: NSFontTraitMask(rawValue: NSFontTraitMask.RawValue(mask)), weight: 0, size: CGFloat(UserDefaultsManagement.fontSize))!
    }
    
    override func paste(_ sender: Any?) {
        super.pasteAsPlainText(nil)
        
        higlightLinks()
        
        guard let content = getAttributedString() else {
            return
        }
        
        //highlightCode(initialFill: true, content: content)
    }
    
    override func keyDown(with event: NSEvent) {
        let range = selectedRanges[0] as! NSRange
        
        //let location = selectedRanges[0].rangeValue.location
        //let attributes = textStorage?.attributes(at: location - 1, effectiveRange: nil)
        //typingAttributes = attributes!
        //Swift.print(attributes)
        // Tab/untab
        if event.keyCode == 48, range.length > 0 {
            if event.modifierFlags.rawValue == 131330 {
                unTab()
            } else {
                tab()
            }
            return
        }
        
        super.keyDown(with: event)
    
        if ![123,124,125,126].contains(event.keyCode) {
            if event.keyCode != 49 {
                higlightLinks()
                
                guard let content = getAttributedString() else {
                    return
                }
                //Swift.print(content)
                //highlightCode(content: content)
            }
        }
    }

    func higlightLinks() {
        guard let storage = textStorage else {
            return
        }
        
        let selected = selectedRanges
        let range = NSMakeRange(0, storage.length)
        let pattern = "(https?:\\/\\/(?:www\\.|(?!www))[^\\s\\.]+\\.[^\\s]{2,}|www\\.[^\\s]+\\.[^\\s]{2,})"
        let regex = try! NSRegularExpression(pattern: pattern, options: [NSRegularExpression.Options.caseInsensitive])
        
        //storage.removeAttribute(NSAttributedStringKey.link, range: range)
        regex.enumerateMatches(
            in: (textStorage?.string)!,
            options: NSRegularExpression.MatchingOptions(),
            range: range,
            using: { (result, matchingFlags, stop) -> Void in
                if let range = result?.range {
                    //if !range.contains((self.selectedRanges.first?.rangeValue.location)!) {
                    //    return
                    //}
                    
                    var str = storage.mutableString.substring(with: range)
                    
                    if str.starts(with: "www.") {
                        str = "http://" + str
                    }
                    
                    guard let url = URL(string: str) else {
                        return
                    }
                    
                    storage.addAttribute(NSAttributedStringKey.link, value: url, range: range)
                }
            }
        )
        
        selectedRanges = selected
    }
    
    public static let _codeBlockPattern = [
        "(?:^\\n|\\A\\n|\\A)",
        "(                        # $1 = the code block -- one or more lines, starting with a space",
        "(?:",
        "    (?:\\p{Z}{4}|\\t+)       # Lines must start with a tab-width of spaces",
        "    .+(?:\\n+)",
        ")+",
        ")",
        "((?=^\\p{Z}{0,4}|\\t[^ \\t\\n])) # Lookahead for non-space at line-start, or end of doc"
        ].joined(separator: "\n")
    
    public static let _codeSpan = [
        "(?<![\\\\`])   # Character before opening ` can't be a backslash or backtick",
        "(`+)           # $1 = Opening run of `",
        "(?!`)          # and no more backticks -- match the full run",
        "(.+?)          # $2 = The code block",
        "(?<!`)",
        "\\1",
        "(?!`)"
        ].joined(separator: "\n")
    
    public static func highlightCode(initialFill: Bool = false, content: NSMutableAttributedString) {
        guard UserDefaultsManagement.codeBlockHighlight else {
            return
        }
        /*
        highlightPattern(initialFill: initialFill, content: content, pattern: EditTextView._codeBlockPattern, options: [
            NSRegularExpression.Options.allowCommentsAndWhitespace,
            NSRegularExpression.Options.anchorsMatchLines
        ])
        
        highlightPattern(initialFill: initialFill, content: content, pattern: EditTextView._codeSpan, options: [
            NSRegularExpression.Options.allowCommentsAndWhitespace,
            NSRegularExpression.Options.anchorsMatchLines,
            NSRegularExpression.Options.dotMatchesLineSeparators,
        ])
 */
        
        /*
        guard let storage = textStorage else {
            return
        }
        
        let paragraphRange = NSMakeRange(0, storage.length)
        
        let boldFont = NSFont.boldSystemFont(ofSize: 13)
        //let italicFont = NSFont.italicSystemFont(ofSize: 13)
        var string = storage.string
        
        // We detect and process dashed headers
        Marklight.headersAtxRegex.matches(string, range: paragraphRange) { (result) -> Void in
            guard let range = result?.range else { return }
            storage.addAttribute(.font, value: boldFont, range: range)
            Marklight.headersAtxOpeningRegex.matches(string, range: range) { (innerResult) -> Void in
                guard let innerRange = innerResult?.range else { return }
                storage.addAttribute(.foregroundColor, value: Marklight.syntaxColor, range: innerRange)
                let syntaxRange = NSMakeRange(innerRange.location, innerRange.length + 1)
                //hideSyntaxIfNecessary(range: syntaxRange)
            }
            Marklight.headersAtxClosingRegex.matches(string, range: range) { (innerResult) -> Void in
                guard let innerRange = innerResult?.range else { return }
                storage.addAttribute(.foregroundColor, value: Marklight.syntaxColor, range: innerRange)
                //hideSyntaxIfNecessary(range: innerRange)
            }
        }
 */
    }
    
    public static var languages: [String]? = nil
    
    public static func highlightPattern(initialFill: Bool = false, content: NSMutableAttributedString, pattern: String, options: NSRegularExpression.Options) {
        let range = NSMakeRange(0, content.length)
        let regex = try! NSRegularExpression(pattern: pattern, options: options)
        
        regex.enumerateMatches(
            in: content.string,
            options: NSRegularExpression.MatchingOptions(),
            range: range,
            using: { (result, matchingFlags, stop) -> Void in
                
                if let range = result?.range {
                    if range.location + range.length  > content.length {
                        return
                    }
                    
                    let code = content.attributedSubstring(from: range)
                    
                    //if !range.contains(((self.selectedRanges.first?.rangeValue.location)! - 1)) && !initialFill {
                    //    return
                    //}
                    
                    //DispatchQueue.global().async {
                        guard let highlightr = Highlightr() else {
                            return
                        }
                        
                        highlightr.setTheme(to: "github")
                        let preDefinedLang = EditTextView.getLanguage(code.string)
                        let highlightedCode = highlightr.highlight(code.string, as: preDefinedLang, fastRender: true)
                        
                        //DispatchQueue.main.async {
                            if range.location + range.length  > content.length {
                                return
                            }
                            
                            if code.string != content.attributedSubstring(from: range).string {
                                return
                            }
                            
                            //let selected = self.selectedRanges
                            content.replaceCharacters(in: range, with: highlightedCode!)
                            
                            let color = NSColor(red:0.97, green:0.97, blue:0.97, alpha:1.0)
                            if let codeFont = NSFont(name: "Source Code Pro", size: CGFloat(UserDefaultsManagement.fontSize)) {
                                content.addAttributes([NSAttributedStringKey.font: codeFont], range: range)
                                content.addAttributes([NSAttributedStringKey.backgroundColor: color], range: range)
                            }
                    
                            //Swift.print(content)
                            
                            //self.textStorage?.setAttributedString(content)
                            
                            //self.selectedRanges = selected
                        //}
                    //}
                }
            }
        )
    }
    
    public static func highlightPatternSync(content: NSMutableAttributedString, pattern: String, options: NSRegularExpression.Options) {
        let range = NSMakeRange(0, content.length)
        let regex = try! NSRegularExpression(pattern: pattern, options: options)
    
        regex.enumerateMatches(
            in: content.string,
            options: NSRegularExpression.MatchingOptions(),
            range: range,
            using: { (result, matchingFlags, stop) -> Void in
                
                if let range = result?.range {
                    let code = content.attributedSubstring(from: range)
                    let preDefinedLang = EditTextView.getLanguage(code.string)
                    
                    guard let highlightr = Highlightr() else {
                        return
                    }
                    
                    highlightr.setTheme(to: "github")
                    guard let highlightedCode = highlightr.highlight(code.string, as: preDefinedLang, fastRender: true) else {
                        return
                    }
                    
                    content.replaceCharacters(in: range, with: highlightedCode)
                    
                    let color = NSColor(red:0.97, green:0.97, blue:0.97, alpha:1.0)
                    if let codeFont = NSFont(name: "Source Code Pro", size: CGFloat(UserDefaultsManagement.fontSize)) {
                        content.addAttributes([NSAttributedStringKey.font: codeFont], range: range)
                        content.addAttributes([NSAttributedStringKey.backgroundColor: color], range: range)
                    }
                }
            }
        )
    }
    
    public static func getLanguage(_ code: String) -> String? {
        if EditTextView.languages == nil {
            EditTextView.languages = Highlightr()?.supportedLanguages()
        }
        
        if code.starts(with: "```") {
            if let newLinePosition = code.rangeOfCharacter(from: CharacterSet.whitespacesAndNewlines) {
                let newLineOffset = newLinePosition.lowerBound.encodedOffset
                if newLineOffset > 3 {
                    let start = code.index(code.startIndex, offsetBy: 3)
                    let end = code.index(code.startIndex, offsetBy: newLineOffset)
                    let range = start..<end
                    
                    if let lang = EditTextView.languages, lang.contains(String(code[range])) {
                        return String(code[range])
                    }
                }
            }
        }
        
        return nil
    }
    
    @objc func tab(_ undoInfo: UndoInfo? = nil) {
        guard let storage = textStorage else {
            return
        }
        
        var range: NSRange
        if let undo = undoInfo {
            range = undo.replacementRange
        } else {
            range = selectedRanges[0] as! NSRange
        }
        
        guard range.length > 0 else {
            return
        }
        
        let code = storage.mutableString.substring(with: range)
        let lines = code.components(separatedBy: CharacterSet.newlines)
        
        var result: String = ""
        var added: Int = 0
        for line in lines {
            if lines.first == line {
                result += "\t" + line
                continue
            }
    
            added = added + 1
            result += "\n\t" + line
        }

        storage.replaceCharacters(in: range, with: result)
        
        let newRange = NSRange(range.lowerBound...range.upperBound + added)
        let undoInfo = UndoInfo(text: result, replacementRange: newRange)
        undoManager?.registerUndo(withTarget: self, selector: #selector(unTab), object: undoInfo)
        self.note?.save(storage)
        
        setSelectedRange(newRange)
        
        guard let content = getAttributedString() else {
            return
        }
        //highlightCode(initialFill: true, content: content)
    }
    
    @objc func unTab(_ undoInfo: UndoInfo? = nil) {
        guard let storage = textStorage else {
            return
        }
        
        var range: NSRange
        if let undo = undoInfo {
            range = undo.replacementRange
        } else {
            range = selectedRanges[0] as! NSRange
        }
        
        let code = storage.mutableString.substring(with: range)
        let lines = code.components(separatedBy: CharacterSet.newlines)
        
        var result: [String] = []
        var removed: Int = 1
        for var line in lines {
            if line.starts(with: "\t") {
                removed = removed + 1
                line.removeFirst()
            }
            
            if line.starts(with: " ") {
                removed = removed + 1
                line.removeFirst()
            }
            
            result.append(line)
        }
        
        let x = result.joined(separator: "\n")
        storage.replaceCharacters(in: range, with: x)
        
        let newRange = NSRange(range.lowerBound...range.upperBound - removed)
        let undoInfo = UndoInfo(text: x, replacementRange: newRange)
        undoManager?.registerUndo(withTarget: self, selector: #selector(tab), object: undoInfo)
        self.note?.save(storage)
        
        setSelectedRange(newRange)
        
        guard let content = getAttributedString() else {
            return
        }
        //highlightCode(initialFill: true, content: content)
    }
}
