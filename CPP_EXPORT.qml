import QtQuick 2.9
import QtQuick.Controls 2.2
import QtQuick.Layouts 1.1
import QtQuick.Dialogs 1.2
import Qt.labs.settings 1.0

import Qt.labs.folderlistmodel 2.1
import QtQml 2.2

import MuseScore 3.0
import FileIO 3.0

MuseScore {
    menuPath: "Plugins.CPP ARR Exporter.Export CPP ARR"
    description: "Generates an CPP ARR"
    version: "0.1a"
    requiresScore: true

    // Total number of extra characters' width added by barlines etc.
    property
    var writeOffset: 0

    // Represents the next upcoming barline boundary
    property
    var barIdxTotal: 0

    // ASCII tab content
    property
    var textContent: "#ifndef SHEET\n#define SHEET\nstatic unsigned short int delay = 100;\nstatic int notes[][2] = {\n"

    // Maximum width of a single line of tab in characters (excludes legends/barlines)
    property
    var maxLineWidth: 112

    FileIO {
        id: cppWriter
        onError: console.log(msg + "\nFilename = " + CPPWriter.source);
    }

    FileDialog {
        id: directorySelectDialog
        title: qsTr("Export CPP...")
        selectFolder: false
        nameFilters: ["Header files (*.h)"]
        selectExisting: false
        selectMultiple: false
        visible: false
        onAccepted: {
            var fname = this.fileUrl.toString().replace("file://", "").replace(/^\/(.:\/)(.*)$/, "$1$2");
            writeTab(fname);
        }
        onRejected: {
            console.log("Cancelled");
            Qt.quit();
        }
        Component.onCompleted: visible = false
    }

    MessageDialog {
        id: errorDialog
        visible: false
        title: "Error"
        text: "Error"
        onAccepted: {
            Qt.quit();
        }

        function openErrorDialog(message) {
            text = message;
            open();
        }
    }

    onRun: {
        if (typeof curScore === 'undefined') {
            console.log("No score");
            errorDialog.openErrorDialog("No score");
        } else {
            console.log("Start");
            console.log("Path: " + filePath);
            console.log("Filename: " + curScore.scoreName + ".mscz");
            directorySelectDialog.open();
        }
    }

    function writeTab(fname) {
        // Generate ASCII tab
        processTab();

        // Write to file
        cppWriter.source = fname;
        console.log("Writing to: " + fname);
        cppWriter.write(textContent);

        // Done; quit
        console.log("Done");
        Qt.quit();
    }

    function processTab() {
        // Create and reset cursor
        var cursor = curScore.newCursor();
        cursor.voice = 0
        cursor.staffIdx = 0;
        cursor.rewind(0);

        while (cursor.segment) {
            var noteID = -10;
            var dur = 0;

            // Write notes/rests
            if (cursor.element) {
                if (cursor.element.type == Element.CHORD) {
                    // Get chord
                    var curChord = cursor.element;
                    for (var i = 0; i < curChord.notes.length; i++) {
                        if (noteID < getNoteID(curChord.notes[i])) {
                            noteID = getNoteID(curChord.notes[i]);
                        }
                    }

                } else if (cursor.element.type == Element.REST) {
                    noteID = -1;
                }
                dur = getDur(cursor.element);
                addArrayElem(noteID, dur);
            }

            cursor.next();
        }
        textContent += "};\n#endif\n";

    }

    function getNoteID(note) {
        var octave = Math.floor(note.pitch / 12) - 1;
        var tpc = note.tpc1 + 1;
        var toneclass = Math.floor(tpc / 7);
        var tonenote = tpc % 7;

        switch (tpc) {
            case 34:
            case 27:
                --octave;
                break;
            case 8:
            case 1:
                ++octave;
                break;
        }

        //              ["F", "C", "G", "D", "A", "E", "B"]
        var offset = [5, 0, 7, 2, 9, 4, 11][tonenote];
        offset += [-2, -1, 0, 1, 2][toneclass];

        var noteID = octave * 12 + offset;

        return noteID;
    }

    function getDur(elem) {
        return elem.actualDuration.numerator / elem.actualDuration.denominator * 32;
    }

    function addArrayElem(noteID, dur) {
        textContent += "{" + noteID + "," + dur + "},\n";
    }
}