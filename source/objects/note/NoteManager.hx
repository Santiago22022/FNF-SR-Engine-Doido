package objects.note;

import states.PlayState;
import objects.note.Note;
import objects.note.Strumline;

class NoteManager
{
    private var parent:PlayState;

    public function new(parent:PlayState)
    {
        this.parent = parent;
    }

    public function update(elapsed:Float):Void
    {
        // This will be filled with logic from PlayState.update()
    }

    public function checkNoteHit(note:Note, strumline:Strumline)
	{
		// This will be filled with logic from PlayState.checkNoteHit()
	}

    function onNoteHit(note:Note, strumline:Strumline)
    {
        // This will be filled with logic from PlayState.onNoteHit()
    }

    function onNoteMiss(note:Note, strumline:Strumline, ghostTap:Bool = false)
    {
        // This will be filled with logic from PlayState.onNoteMiss()
    }

    function onNoteHold(note:Note, strumline:Strumline)
    {
        // This will be filled with logic from PlayState.onNoteHold()
    }

    public function popUpRating(note:Note, strumline:Strumline, miss:Bool = false)
    {
        // This will be filled with logic from PlayState.popUpRating()
    }

    public function updateNotes()
    {
        // This will be filled with logic from PlayState.updateNotes()
    }
}
