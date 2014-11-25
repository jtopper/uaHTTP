### uaHTTP display annotation functions ###

### Functions ###

sub display_annotation {

my ($handle, $content, $uaresponse, $username) = @_;
my ($response, $request, $html);

my %form = %$content;

my $canonname = $uaresponse->child("name")->value;
my $userid    = $uaresponse->first("userid")->value;

defined($form{folder})  || die "No folder passed to display_annotation\n";
defined($form{message}) || die "No message passed to display_annotation\n";

$request = clean EDF::Object("request", \"message_list");
$request->addChild("messageid", $form{message});
$request->addChild("folderid", $form{folder});

$response = $handle->request($request);

$request->DESTROY;

die "Message #$form{message} does not exist" if ($response->value eq "message_not_exist"); 
die "Folder #$form{folder} does not exist" if ($response->value eq "folder_not_exist"); 

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

function setEntrypoint() {
  document.entryForm.annotation.focus();
}

// -->
</script>


</head>

<body onLoad="setEntrypoint()">

<form method="post" action="addnote" name="entryForm">
<input type="hidden" name="folder" value="$form{folder}">
<input type="hidden" name="message" value="$form{message}">

<table width="100%" border="0" cellspacing="0" cellpadding="0" class="headers">\n~;

###

$html .= qq~
<tr>
<td><table border="0" cellspacing="0" cellpadding="0" class="title">~;

### Server no longer gives $messof
#$html .= qq~<tr>\n<td colspan="2">Message $form{message} ($messof~ . &ordinal($messof) . qq~ of $nummsgs) in ~ . $reply->{foldername}[0];
$html .= qq~<tr>\n<td colspan="2">Message $form{message} in ~ . $reply->{foldername}[0];

$html .= ($message->{'marktype'})?qq~ [Caught-up]~:qq~ [Re-read]~ if ($message->{read});

$html .= qq~</td>\n</tr>~;

$html .= qq~<tr>\n<td>Date:&nbsp;</td><td class="htext">~ . &parseDate($message->{date}[0]) . qq~</td>\n</tr>~;
$html .= qq~<tr>\n<td>From:&nbsp;</td><td class="htext">~;
$html .= $message->{fromname}[0];

$html .= qq~</td>\n</tr>~;
$html .= qq~<tr>\n<td>To:&nbsp;</td><td class="htext">~ . parse_colours($message->{toname}[0]) . qq~</td>\n</tr>~ if (defined($message->{toname}[0]));

$html .= qq~<tr>\n<td>Subject:&nbsp;</td><td class="htext">~ . parse_colours(escape_html($message->{subject}[0], 1)) . qq~</td>\n</tr>~ if (defined($message->{subject}[0]));

if ($message->{replyto}) {

  $html .= qq~<tr>\n<td valign="top"><nobr>In-Reply-To:&nbsp;</nobr></td><td class="htext">~;

  $response->root->child("message")->child("replyto");

  my $notfirsttime = 0;

  do {

    $html .= qq~, ~ if ($notfirsttime++);

    my $message = $response->value;
    my %reply   = $response->elements;

    $html .= qq~$message~;
    $html .= qq~ (in $reply{foldername}[0])~ if ($reply{foldername}[0]);

  } while ($response->next("replyto"));

  $html .= qq~</td>\n</tr>~;
 
}

if ($message->{replyby}) {

  $html .= qq~<tr>\n<td valign="top"><nobr>Replied-To-In:&nbsp;</nobr></td><td class="htext">~;

  $response->root->child("message")->child("replyby");

  my $notfirsttime = 0;

  do {

    $html .= qq~, ~ if ($notfirsttime++);

    my $message = $response->value;
    my %reply   = $response->elements;

    $html .= qq~$message~;
    $html .= qq~ (in $reply{foldername}[0])~ if ($reply{foldername}[0]);

  } while ($response->next("replyby"));

  $html .= qq~</td>\n</tr>~;
 
}

$html .= qq~</table></td>~;

###

$text = escape_html($message->{text}[0], 1);

$html .= qq~<tr width="100%">\n<td colspan="2"><div class="message" id="messagebox">$text~;

if ($response->root->child("message")->child("votes")) {

  my %options = ();

#  if ($response->value == 1) { # Yes/No vote
#    %options = (0 => "No", 1 => "Yes",);
#  } elsif ($response->value == 2) { # Multiple vote

    if ($response->parent->child("vote")) {

      do {
        $response->push;
        my $value = $response->value;
        $options{$value} = $response->child("text")->value;
        $response->pop;
      } while ($response->next("vote"));

    }

#  }

  my $myvote;

  if ($response->root->child("message")->child("vote")) {

    do {
      $response->push;
      my $value = $response->value;

      if ($response->child("userid")) {

        do {
          $myvote = $value if ($userid == $response->value);
        } while ($response->next("userid"));

      }

      $response->pop;
    } while ($response->next("vote"));

  }

  $html .= qq~<div class="vote"><table border="0" cellpadding="0" cellspacing="0">\n~;

  foreach $key (sort {$a <=> $b} keys %options) {
    if ($myvote == $key) {
      $html .= qq~<tr><td><img src="$IMAGEDIR/v.gif" width="16" height="13" alt="*"</td><td>$options{$key}</td></tr>\n~;
    } else {
      $html .= qq~<tr><td><img src="$IMAGEDIR/bv.gif" width="16" height="13" alt=" "</td><td>$options{$key}</td></tr>\n~;
    }
  }

  $html .= qq~</table></div>\n~;

}

$html .= qq~</div></td>\n</tr>~;

###

if ($message->{edit}) {

  $response->root->child("message")->child("attachment");

  $html .= qq~<tr width="100%">\n<td colspan="2"><table class="title" cellspacing="0" cellpadding="0" border="0" width="100%">\n~;

  do {

    my %note = $response->elements;

    if ($note{'content-type'}[0] eq 'text/x-ua-annotation') {

      $html .= qq~<tr>\n<td style="vertical-align: middle"><nobr>Annotated-by $note{fromname}[0] ~ .
               formatTime($note{date}[0] - $message->{date}[0]) .
               qq~ later:&nbsp;</nobr></td>\n<td class="noteholder" valign="top"><div class="notetext">~ .
               escape_html($note{text}[0]) .
               qq~</div></td>\n</tr>~;

    }

  } while ($response->next("attachment"));

  $html .= qq~</table></td>\n</tr>~;
 
}

###

$html .= qq~

<tr width="100%">
<td colspan="2">Annotation: <input type="text" maxlength="100" class="message" name="annotation"></td>
</tr>

<tr width="100%">
<td colspan="2" class="buttonhole"><input type="submit" name="Submit" value="Post annotation" class="button"></td>
</tr>

</table>

</form>

</body>
</html>
~;

return $html;

}

###
1;
