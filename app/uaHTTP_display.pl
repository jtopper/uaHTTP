### uaHTTP display functions ###

require "uaHTTP_display_folders.pl";
require "uaHTTP_display_folder.pl";
require "uaHTTP_display_message.pl";
require "uaHTTP_display_subscribe.pl";
require "uaHTTP_display_posting.pl";
require "uaHTTP_add_message.pl";
require "uaHTTP_delete_message.pl";
require "uaHTTP_hold_message.pl";
require "uaHTTP_display_folderinfo.pl";
require "uaHTTP_display_userinfo.pl";
require "uaHTTP_userlogout.pl";
require "uaHTTP_display_wholist.pl";
require "uaHTTP_catchup_messages.pl";
require "uaHTTP_display_search.pl";
require "uaHTTP_display_banner.pl";
require "uaHTTP_process_vote.pl";
require "uaHTTP_display_annotation.pl";
require "uaHTTP_add_annotation.pl";
require "uaHTTP_hold_thread.pl";
require "uaHTTP_display_move.pl";
require "uaHTTP_move_message.pl";
require "uaHTTP_display_announcements.pl";
require "uaHTTP_change_message.pl";
require "uaHTTP_send_page.pl";
require "uaHTTP_display_page.pl";
require "uaHTTP_unset_nocontact.pl";
require "uaHTTP_quickjump.pl";
require "uaHTTP_user_edit.pl";
require "uaHTTP_recover_pages.pl";
require "uaHTTP_folder_edit.pl";

### Functions ###

sub not_coded {

return qq~
<html>
<head>
<title></title>

<link rel=stylesheet type="text/css" href="ua.css">

</head>

<body>
<br>
<p>This feature is not coded in yet.</p>
</body>
</html>
~;

}

###

sub get_folders {

my $edf = shift;

local @::folders = ();
local $::depth   = 0;

if ($edf->child("folder")) {
  get_foldersR($edf);
}

return @::folders;

}

###

sub get_foldersR {

my $edf = shift;

do {
  $edf->push;
  push(@::folders, { $edf->value => { $edf->elements, depth => $::depth } } );
  $edf->pop;
  if ($edf->child("folder")) {
    $::depth++;
    get_foldersR($edf);
    $::depth--;
    $edf->parent;
  }
} while ($edf->next("folder"));

return;

}

###

sub get_messages {

my $edf = shift;

local @::messages = ();
local $::depth    = 0;
local $::delta    = 0;
local $::unread   = ($form{messages} eq "unread");

if ($edf->child("message")) {
  get_messagesR($edf);
}

return @::messages;

}

###

sub get_messagesR {

my $edf = shift;

do {
  $edf->push;
  if ($::unread) {
    $edf->push;
    if (! $edf->child("read")) {
      push(@::messages, { $edf->value => { $edf->elements, depth => ($::depth - $::delta) } } );
    } else {
      $::delta++;
    }
    $edf->pop;
  } else {
    push(@::messages, { $edf->value => { $edf->elements, depth => ($::depth - $::delta) } } );
  }

  $edf->pop;
  if ($edf->child("message")) {
    $::depth++;
    get_messagesR($edf);
    $::depth--;
    $edf->parent;
  }
  $::delta = 0;
} while ($edf->next("message"));

return;

}

###
1;
