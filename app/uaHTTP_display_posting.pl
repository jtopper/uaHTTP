### uaHTTP display posting functions ###

### Functions ###

sub display_posting {

my ($handle, $content, $uaresponse, $username) = @_;
my ($response, $request, $html);

my %form = %$content;

my $canonname = $uaresponse->child("name")->value;
my $userid    = $uaresponse->first("userid")->value;

my $title = "New Message";

my $isareply = defined($form{message}) && defined($form{folder});

if ($isareply) {

  $title = "Reply to message $form{message}";

  $request = clean EDF::Object("request", \"message_list");
  $request->addChild("messageid", $form{message});
  $request->addChild("folderid", $form{folder});

  $response = $handle->request($request);

  $request->DESTROY;

  die "Message #$folder{message} does not exist" if ($response->value eq "message_not_exist"); 
  die "Folder #$folder{folder} does not exist" if ($response->value eq "folder_not_exist");

  unless ($response->value eq "message_list") {
    die "Unknown response: " . $response->value . "\n";
  }

  $response->child("message");
  $message = { $response->elements };

}

$request = clean EDF::Object("request", \"folder_list");
$request->addChild("searchtype", 3);
$response = $handle->request($request);
$request->DESTROY;

unless ($response->value eq "folder_list") {
  die "Unknown response: " . $response->value . "\n";
}

my @folders = get_folders($response);

#use Data::Dumper;print STDERR Dumper(@folders);

my %dropdown = ();
my $replyid = $form{folder};

if ($isareply) {
FOLDERS:
  foreach $folder (@folders) {
    foreach $key (keys %$folder) {
      if ($key == $form{folder}) {
        $replyid = %$folder->{$key}{replyid}[0] || $key;
        last FOLDERS;
      }
    }
  }
}

{
  my $selectkey = $replyid || 384; # Private by default
  foreach $folder (@folders) {
    foreach $key (keys %$folder) {
      my $selected = ($key == $selectkey)?" selected":"";
      $dropdown{lc(%$folder->{$key}{name}[0])} = qq~<option value="$key"$selected>~ . %$folder->{$key}{name}[0];
    }
  }
}

my $dropdown = join("\n", map { $dropdown{$_} } sort keys %dropdown);

$html .= qq~
<html>
<head>
<title>$title</title>

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

function setEntrypoint(isareply) {

if (isareply) {
  var xbox = document.entryForm.messagetext;
  xbox.focus();
  if (xbox.createTextRange) {
    var xrange = xbox.createTextRange();
    xrange.moveStart('character', xbox.value.length);
    xrange.collapse();
    xrange.select();
  }
} else {
  document.entryForm.toname.focus();
}

}

// -->
</script>

</head>

<body onLoad="setEntrypoint($isareply)">
<form action="addmessage" method="post" name="entryForm">
<input type="hidden" name="message" value="$form{message}">
<input type="hidden" name="replyfolder" value="$form{folder}">
<table width="100%" border="0" cellspacing="0" cellpadding="0" class="headers"><tr>
<td><table border="0" cellspacing="0" cellpadding="0" class="title">~;

$html .= qq~<tr>\n<td>Folder:&nbsp;</td><td class="htext"><select name="folder" class="headinput">$dropdown</select></td>\n</tr>~;

$html .= qq~<tr>\n<td>From:&nbsp;</td><td class="htext"><a href="userinfo?user=~ . escape_html($userid) . qq~">~ . $canonname . qq~</a></td>\n</tr>~;
$html .= qq~<tr>\n<td>To:&nbsp;</td><td class="htext"><input class="headinput" type="text" name="toname" value="~ . escape_html($message->{fromname}[0]) . qq~" size="80"></td>\n</tr>~;
$html .= qq~<tr>\n<td>Subject:&nbsp;</td><td class="htext"><input class="headinput" type="text" name="subject" value="~ . escape_html($message->{subject}[0]) . qq~" size="80"></td>\n</tr>~;

$html .= qq~<tr>\n<td valign="top"><nobr>In-Reply-To:&nbsp;</nobr></td><td class="htext">$form{message}</td>\n</tr>~ if defined($form{message});
 
$html .= qq~</table></td>~;

$html .= qq~\n</tr>\n~;

$text = ($isareply)?escape_html(join("\n", map { "> $_" } wrap_text($message->{text}[0], 78)), 0, 1):"";

$html .= qq~<tr width="100%">\n<td colspan="2"><textarea name="messagetext" rows="16" wrap="virtual" cols="80" class="message">$text\n\n</textarea></td>\n</tr>~;

$html .= qq~<tr width="100%">\n<td colspan="2" class="buttonhole"><input type="submit" name="Submit" value="Post message" class="button"></td>\n</tr></table>
</form>
</body>
</html>
~;

return $html;

}

###
1;
