### uaHTTP display message functions ###

### Functions ###

sub display_message {

local ($handle, $content, $uaresponse, $username) = @_;
local ($response, $request, $html);

local %form = %$content;

my $canonname = $uaresponse->child("name")->value;
my $userid    = $uaresponse->first("userid")->value;

defined($form{folder})  || die "No folder passed to display_message\n";
defined($form{message}) || die "No message passed to display_message\n";

$request = clean EDF::Object("request", \"message_list");
$request->addChild("messageid", $form{message});
$request->addChild("folderid", $form{folder});

$response = $handle->request($request);

$request->DESTROY;

die "Message #$form{message} does not exist in folder #$form{folder}\n" if ($response->value eq "message_not_exist"); 
die "Folder #$form{folder} does not exist\n" if ($response->value eq "folder_not_exist"); 

unless ($response->value eq "message_list") {
  die "Unknown response: " . $response->value . "\n";
}

#use EDF::Object qw(display pretty); display pretty $response->toEDF;

#$nummsgs = $response->first("nummsgs")->value;
#$response->parent;

$reply = { $response->elements };

$response->child("message");
$message = { $response->elements };

$nummsgs = $reply->{nummsgs}[0];
$messof = $message->{msgpos}[0];

$html .= qq~
<html>
<head>
<title>Message $form{message}</title>
<link rel=stylesheet type="text/css" href="ua.css">

<script language="Javascript">
<!--

function updateMessageList(mid, fid) {

  if (fid) {
    parent.folders.openFolder(fid);
    parent.messagelist.location = "showfolder?folder=" + fid + "&amp;message=" + mid;
  } else {
    parent.messagelist.openMessage(mid, true);
  }

}

// -->
</script>

</head>

~;

if ($form{openfolder}) {
  $html .= qq~<body onLoad="updateMessageList($form{'message'}, $form{'folder'})">~;
} else {
  $html .= qq~<body>~;
}

$html .= qq~

<form method="post" action="vote" name="vote">
<input type="hidden" name="folder" value="$form{'folder'}">
<input type="hidden" name="message" value="$form{'message'}">

<table width="100%" border="0" cellspacing="0" cellpadding="0" class="headers"><tr>
<td><table border="0" cellspacing="0" cellpadding="0" class="title">~;

### Server no longer gives $messof
#$html .= qq~<tr>\n<td colspan="2">Message $form{message} ($messof~ . &ordinal($messof) . qq~ of $nummsgs) in ~ . $reply->{foldername}[0];
$html .= qq~<tr>\n<td colspan="2">Message $form{message} in <a href="showfolder?folder=$form{folder}&noload=1" target="messagelist">~ . $reply->{foldername}[0] . qq~</a>~;

$html .= ($message->{'marktype'})?qq~ [Caught-up]~:qq~ [Re-read]~ if ($message->{read});

$html .= qq~</td>\n</tr>~;

$html .= qq~<tr>\n<td>Date:&nbsp;</td><td class="htext">~ . &parseDate($message->{date}[0]) . qq~</td>\n</tr>~;
$html .= qq~<tr>\n<td>From:&nbsp;</td><td class="htext">~;

if ($message->{fromid}[0]) {
  $html .= qq~<a href="userinfo?user=~ . escape_html($message->{fromid}[0]) . qq~">~ . $message->{fromname}[0] . qq~</a>~;
} else {
  $html .= $message->{fromname}[0];
}

$html .= qq~</td>\n</tr>~;

if ($message->{toid}[0]) {
  $html .= qq~<tr>\n<td>To:&nbsp;</td><td class="htext"><a href="userinfo?user=~ . escape_html($message->{toid}[0]) . qq~">~ . parse_colours($message->{toname}[0]) . qq~</a></td>\n</tr>~ if (defined($message->{toname}[0]));
} else {
  $html .= qq~<tr>\n<td>To:&nbsp;</td><td class="htext">~ . parse_colours($message->{toname}[0]) . qq~</td>\n</tr>~ if (defined($message->{toname}[0]));
}

$html .= qq~<tr>\n<td>Subject:&nbsp;</td><td class="htext">~ . parse_colours(escape_html($message->{subject}[0], 1)) . qq~</td>\n</tr>~ if (defined($message->{subject}[0]));

if ($message->{replyto}) {

  $html .= qq~<tr>\n<td valign="top"><nobr>In-Reply-To:&nbsp;</nobr></td><td class="htext">~;

  $response->root->child("message")->child("replyto");

  my $notfirsttime = 0;
  my $oldfoldername;

  do {

    $html .= qq~, ~ if ($notfirsttime++);

    my $message = $response->value;
    my %reply   = $response->elements;

    $html .= qq~<a href="showmessage?folder=~ .
      ($reply{folderid}[0] || $form{folder}) .
      qq~&message=$message" onClick="updateMessageList('$message', '$reply{folderid}[0]')">$message</a>~;

    if ( ($reply{foldername}[0]) && ($reply{foldername}[0] ne $oldfoldername) ) {
      $html .= qq~ (in $reply{foldername}[0])~;
      $oldfoldername = $reply{foldername}[0];
    }

  } while ($response->next("replyto"));

  $html .= qq~</td>\n</tr>~;
 
}

if ($message->{replyby}) {

  $html .= qq~<tr>\n<td valign="top"><nobr>Replied-To-In:&nbsp;</nobr></td><td class="htext">~;

  $response->root->child("message")->child("replyby");

  my $notfirsttime = 0;
  my $oldfoldername;

  do {

    $html .= qq~, ~ if ($notfirsttime++);

    my $message = $response->value;
    my %reply   = $response->elements;

    $html .= qq~<a href="showmessage?folder=~ .
      ($reply{folderid}[0] || $form{folder}) .
      qq~&amp;message=$message" onClick="updateMessageList('$message', '$reply{folderid}[0]')" title="$reply{fromname}[0]">$message</a>~;

    if ( ($reply{foldername}[0]) && ($reply{foldername}[0] ne $oldfoldername) ) {
      $html .= qq~ (in $reply{foldername}[0])~;
      $oldfoldername = $reply{foldername}[0];
    }

  } while ($response->next("replyby"));

  $html .= qq~</td>\n</tr>~;
 
}

if ($message->{move}) {

  $html .= qq~<tr>\n<td valign="top"><nobr>Moved-From:&nbsp;</nobr></td><td class="htext">~;

  $response->root->child("message")->child("move");

  my $notfirsttime = 0;

  do {

    $html .= qq~, ~ if ($notfirsttime++);

    my $time = $response->value;
    my %move = $response->elements;

    $html .= qq~<a href="showfolder?folder=$move{'folderid'}[0]" target="messagelist">$move{'foldername'}[0]</a> (on&nbsp;~;
    $html .= &parseDate($time);
    $html .= qq~)~;

  } while ($response->next("move"));

  $html .= qq~</td>\n</tr>~;

}

$html .= qq~</table></td>~;

$html .= qq~<td align="right" valign="top">~;

$html .= qq~<table border="0" cellspacing="0" cellpadding="0" class="title" bgcolor="#ffffff"><tr>\n~;

$html .= qq~<td><table border="0" cellspacing="0" cellpadding="2" class="title" >~;

# ANNOTATE MESSAGE
$html .= qq~<tr><td><a href="notemessage?folder=$form{folder}&amp;message=$form{message}"><img src="$IMAGEDIR/note.gif" width="16" height="13" alt=" " border="0" accesskey="a">&nbsp;Annotate</a></td></tr>\n~ if ( canAnnotate($userid) );

# MOVE MENU
$html .= qq~<tr><td><a href="displaymove?folder=$form{folder}&amp;message=$form{message}"><img src="$IMAGEDIR/mt.gif" width="16" height="13" alt=" " border="0" accesskey="m">&nbsp;Move</a></td></tr>\n~ if ( canMove($userid) );

# DELETE MESSAGE
$html .= qq~<tr><td><a href="deletemessage?folder=$form{folder}&amp;message=$form{message}" target="messagelist"><img src="$IMAGEDIR/del.gif" width="16" height="13" alt=" " border="0" accesskey="d">&nbsp;Delete</a></td></tr>\n~ if ( canDelete($userid) );

$html .= qq~</table></td>\n<td><table border="0" cellspacing="0" cellpadding="2" class="title">\n~;

# REPLY TO MESSAGE
$html .= qq~<tr><td><a href="postmessage?folder=$form{folder}&amp;message=$form{message}"><img src="$IMAGEDIR/rep.gif" width="16" height="13" alt=" " border="0" accesskey="r">&nbsp;Reply</a></td></tr>\n~;

# HOLD MESSAGE
$html .= qq~<tr><td><a href="holdmessage?folder=$form{folder}&amp;message=$form{message}" target="messagelist"><img src="$IMAGEDIR/cm.gif" width="16" height="13" alt=" " border="0" accesskey="h">&nbsp;Hold</a></td></tr>\n~;

# HOLD THREAD
$html .= qq~<tr><td><a href="holdthread?folder=$form{folder}&amp;message=$form{message}" target="messagelist"><img src="$IMAGEDIR/ht.gif" width="16" height="13" alt=" " border="0" accesskey="t">&nbsp;Hold&nbsp;Thread</a></td></tr>\n~;

# CATCHUP THREAD
$html .= qq~<tr><td><a href="catchup?folder=$form{folder}&amp;message=$form{message}" target="messagelist"><img src="$IMAGEDIR/ct.gif" width="16" height="13" alt=" " border="0" accesskey="c">&nbsp;Catch&nbsp;Up</a></td></tr>\n~;

$html .= qq~</table></td>\n~;

$html .= qq~</tr></table>~;

$html .= qq~</td>\n</tr>\n~;

$text = escape_html($message->{text}[0], 1);

$html .= qq~<tr width="100%">\n<td colspan="2"><div class="message" id="messagebox">$text~;

#define VOTE_NAMED 1
#define VOTE_CHOICE 2
#define VOTE_CHANGE 4
#define VOTE_PUBLIC 8
#define VOTE_PUBLIC_CLOSE 16
#define VOTE_CLOSED 32
#define VOTE_MULTI 64 // Added in v2.6-beta4
#define VOTE_INTVALUES 128 // Added in v2.6-beta16
#define VOTE_PERCENT 256 // Added in v2.6-beta16
#define VOTE_STRVALUES 512 // Added in v2.6-beta16

if ($response->root->child("message")->child("votes")) {

  $response->child;
  my $votetype   = $response->first("votetype") && $response->value;
  my $totalvotes = $response->first("numvotes") && $response->value;
  my $voted      = $response->first("voted") && $response->value;

  my %options = ();
  my $myvote;

  if ($response->first("vote")) {

    do {
      $response->push;
      my $value = $response->value;
      $options{$value}{'text'}     = $response->child("text")->value;
      $options{$value}{'numvotes'} = $response->first("numvotes") && $response->value;
      $myvote = $value if ($response->first("voted"));
      $response->pop;
    } while ($response->next("vote"));

    $voted ||= defined($myvote);

  }

  $html .= qq~<div class="vote"><table border="0" cellpadding="0" cellspacing="0">\n~;

  my $closed = $votetype & 32; # vote closed
  my $public = ( ( $closed && ($votetype & 16) ) || ($votetype & 8) ); # vote closed and public on close / or public

  foreach $key (sort {$a <=> $b} keys %options) {

    $html .= qq~<tr>~;

    if ($public && $totalvotes) {
      my $pc = 100 * $options{$key}{'numvotes'} / $totalvotes;
      $html .= sprintf('<td align="right">&nbsp;%u %s&nbsp;</td><td><img src="' . $IMAGEDIR . '/bar/%03.0f.png" height="13" alt="%u%%" hspace="2"></td>', $options{$key}{'numvotes'}, ($options{$key}{'numvotes'} == 1)?"vote":"votes", $pc, $pc);
    }

    if ($myvote == $key) {
      $html .= qq~<td><img src="$IMAGEDIR/v.gif" width="16" height="13" alt="*"></td>~;
    } elsif ($voted || $closed) {
      $html .= qq~<td><img src="$IMAGEDIR/bv.gif" width="16" height="13" alt=" "></td>~;
    } else {
      $html .= qq~<td><input type="radio" name="voteid" value="$key"></td>~;
    }

    $html .= qq~<td>~ . escape_html($options{$key}{'text'}, 1) . qq~</td></tr>\n~;

  }

  $html .= qq~</table></div>\n~;

  $html .= qq~<div style="margin-left: 12px; margin-top: 6px;"><input type="submit" name="Submit" value="Vote" class="button"></div>\n~ unless ($voted || $closed);

}

$html .= qq~</div></td>\n</tr>~;

###

if ($message->{edit}) {

  $response->root->child("message")->child("attachment");
    
  $html .= qq~<tr width="100%">\n<td colspan="2"><table class="title" cellspacing="0" cellpadding="0" border="0" width="100%">\n~;

  do {
    
    my %note = $response->elements;

    if ($note{'content-type'}[0] eq 'text/x-ua-annotation') {

      $html .= qq~<tr>\n<td style="vertical-align: middle"><nobr>Annotated-by  <a href="userinfo?user=~ .
               escape_html($note{fromid}[0]) .
               qq~">$note{fromname}[0]</a> ~ .
               formatTime($note{date}[0] - $message->{date}[0]) .
               qq~ later:&nbsp;</nobr></td>\n<td class="noteholder" valign="top"><div class="notetext">~ .
               escape_html($note{text}[0], 1) .
               qq~</div></td>\n</tr>~;

	}

  } while ($response->next("attachment"));

  $html .= qq~</table></td>\n</tr>~;
 
}

###

$html .= qq~

<script language="Javascript">
<!--

var isIE = false;
var isIE55 = false;
var isNS = false;
var isNS6 = false;

-->
</script>

<script src="ua.js"></script>

<script language="Javascript">
<!--

var xhasmonoprop = false;
var xhasstitchurls = false;

function monoprop() {

if (xhasmonoprop) {
  xmessagebox = document.getElementById("messagebox");
  xmessagebox.className = (xmessagebox.className == "messagemono")?"message":"messagemono";
}

}

if (isIE || isNS6) {

  document.write('<tr><td colspan="2"><input type="checkbox" onClick="monoprop()" id="monocheck"> Monospaced font');
  xhasmonoprop = true;

  if (isIE55 || isNS6) {
    document.write(' / <input type="checkbox" onClick="stitchurls()" id="stitchcheck"> Stitch URLs');
    xhasstitchurls = true;
  }

  document.write('</td></tr>');

}

~;

my $text;

(my $text = $message->{text}[0]) =~ s/\s//g;
my $ratio = ( $text =~ s/[\W_]//g ) / ( length($text) || 1);

if ($ratio >= 1) {
  $html .= qq~if (xhasmonoprop) {\n  monoprop();\n  document.getElementById("monocheck").checked = true;\n}\n~;
}

$html .= qq~
// -->
</script>

</table>

</form>

<!-- $ratio -->

</body>
</html>
~;

return $html;

}

###

sub parseDate {

#($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst)

my @months = qw(January February March April May June July August September October November December);
my @days   = qw(Sunday Monday Tuesday Wednesday Thursday Friday Saturday);
my $time;
my @time = localtime(shift);

$time = join(" ", "$days[$time[6]],", $time[3], $months[$time[4]], $time[5] + 1900, "-", join(":", map { substr("00$_", -2) } @time[2, 1]) );

return $time;

}

###

sub formatTime {

my $time = shift;
my($days, $hours, $mins, $secs);

$time -= 86400 * ($days  = int($time / 86400));
$time -=  3600 * ($hours = int($time / 3600));
$time -=    60 * ($mins  = int($time / 60));
                  $secs  = int($time);

return ($days  == 1)?"1 day":"$days days"       if ($days);
return ($hours == 1)?"1 hour":"$hours hours"    if ($hours);
return ($mins  == 1)?"1 minute":"$mins minutes" if ($mins);
return ($secs  == 1)?"1 second":"$secs seconds";

}

###

sub canAnnotate {

my $userid = shift;

# witness / sysop

return 1 if ($uaresponse->root->first("accesslevel")->value >= 4);

# editor

return 1 if ($EDITOR{$userid}{$form{'folder'}});

# poster / postee

if ($message->{edit}) {
  my $return = 0;
  $response->push;
  my %elements;
  $response->root->child("message")->child("attachment");
  do {
    %elements = $response->elements;
    $return = 1 if ( ($elements{'content-type'}[0] eq 'text/x-ua-annotation') && ($elements{fromid}[0] == $userid) );
  } while ($response->next("attachment"));
  $response->pop;
  return 0 if ($return);
}

return 1 if ($message->{fromid}[0] == $userid);
return 1 if ($message->{toid}[0]   == $userid);

#otherwise

return 0

}

###

sub canDelete {

my $userid = shift;

# poster

return 1 if ($message->{fromid}[0] == $userid);

# witness / sysop

return 1 if ($uaresponse->root->first("accesslevel")->value >= 4);

# editor

return 1 if ($EDITOR{$userid}{$form{'folder'}});

#otherwise

return 0

}

###

sub canMove {

my $userid = shift;

# witness / sysop

return 1 if ($uaresponse->root->first("accesslevel")->value >= 4);

# editor

return 1 if ($EDITOR{$userid}{$form{'folder'}});

#otherwise

return 0

}

###
1;
