//
//  SourceEditorCommand.swift
//  TODO
//
//  Created by Denis Poifol on 21/08/2017.
//  Copyright © 2017 Denis Poifol. All rights reserved.
//

import Foundation
import XcodeKit

private enum Command: String {
    case TODO
    case FIXME
}

private enum ExtensionError: String, Error {
    case unrecognizedCommand
}

class SourceEditorCommand: NSObject, XCSourceEditorCommand {

    func perform(with invocation: XCSourceEditorCommandInvocation, completionHandler: @escaping (Error?) -> Void ) -> Void {
        guard let command = Command(rawValue: invocation.commandIdentifier) else {
            completionHandler(ExtensionError.unrecognizedCommand)
            return
        }
        let comment = string(for: command)
        var updatedSelections: [XCSourceTextRange] = []
        for selectionObject in invocation.buffer.selections {
            guard
                let selection = selectionObject as? XCSourceTextRange,
                let newSelection = replace(selection, in: invocation.buffer, with: comment) else {
                    continue
            }
            updatedSelections.append(newSelection)
        }
        invocation.buffer.selections.removeAllObjects()
        for selection in updatedSelections {
            invocation.buffer.selections.add(selection)
        }
        completionHandler(nil)
    }

    // MARK - private methods

    private func replace(_ selection: XCSourceTextRange, in buffer: XCSourceTextBuffer, with text: String) -> XCSourceTextRange? {
        if selection.start.line == selection.end.line {
            let line = selection.start.line
            let newSelection = XCSourceTextRange(
                start: selection.start,
                end: XCSourceTextPosition(
                    line: selection.start.line,
                    column: selection.start.column + text.characters.count
                )
            )
            guard var lineToChange = buffer.lines[line] as? String else { return nil }
            let subRangeStartIndex = lineToChange.index(lineToChange.startIndex, offsetBy: selection.start.column)
            guard selection.end.column > selection.start.column else {
                lineToChange.insert(contentsOf: text.characters, at: subRangeStartIndex)
                buffer.lines[selection.start.line] = lineToChange
                return newSelection
            }
            let subRangeEndIndex = lineToChange.index(lineToChange.startIndex, offsetBy: selection.end.column - 1)
            lineToChange.replaceSubrange(subRangeStartIndex...subRangeEndIndex, with: text)
            buffer.lines[selection.start.line] = lineToChange
            return newSelection
        } else if selection.start.line + 1 == selection.end.line {
            guard
                let firstLine = buffer.lines[selection.start.line] as? String,
                let lastLine = buffer.lines[selection.end.line] as? String
                else { return nil }
            if selection.end.column == 0 {
                return replace(
                    XCSourceTextRange(
                        start: selection.start,
                        end: XCSourceTextPosition(
                            line: selection.start.line,
                            column: firstLine.characters.count
                        )
                    ),
                    in: buffer, with: text)
            }
            let groupedLines = firstLine.appending(lastLine).replacingOccurrences(of: "\n", with: "")
            let newSelection = XCSourceTextRange(
                start: selection.start,
                end: XCSourceTextPosition(
                    line: selection.start.line,
                    column: groupedLines.characters.count + selection.end.column - lastLine.characters.count + 1
                )
            )
            buffer.lines.removeObject(at: selection.end.line)
            buffer.lines.replaceObject(at: selection.start.line, with: groupedLines)
            return replace(newSelection, in: buffer, with: text)
        } else {
            let newSelection = XCSourceTextRange(
                start: selection.start,
                end: XCSourceTextPosition(
                    line: selection.start.line + 1,
                    column: selection.end.column
                )
            )
            let indexSet: IndexSet = IndexSet(integersIn: (selection.start.line + 1)...(selection.end.line - 1))
            buffer.lines.removeObjects(at: indexSet)
            return replace(newSelection, in: buffer, with: text)
        }
    }

    private func string(for command: Command) -> String {
        let date = Date()
        let dateString = DateFormatter.short.string(from: date)
        let userName = NSFullUserName()

        var comment = "// \(command) (\(userName)) \(dateString) "
        comment.append("<#")
        comment.append(command.rawValue)
        comment.append("#>")
        return comment
    }
}
