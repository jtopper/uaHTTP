### uaHTTP display folder info functions ###

### Functions ###

sub display_folderinfo {

my ($handle, $content, $uaresponse, $username) = @_;
my ($response, $request, $html);

local %form = %$content;

my $canonname = $uaresponse->child("name")->value;
my $userid    = $uaresponse->first("userid")->value;

defined($form{folder}) || die "No folder passed to display_folderinfo\n";

$request = clean EDF::Object("request", \"folder_list");
$request->addChild("searchtype", 3);
$request->addChild("folderid", $form{folder});

$response = $handle->request($request);

$request->DESTROY;

unless ($response->value eq "folder_list") {
  die "Unknown response: " . $response->value . "\n";
}

$response->child("folder") || die "No such folder #$form{folder}";

$folderid = $response->value;

$response->push;
$info = $response->child("info") && $response->child("text") && $response->value;
$info ||= "";
$response->pop;

my $foldername = $response->child("name")->value;

if ($response->first("member")) {
  do {
    $response->push;
    my $id = $response->value;
    my $name = $response->child("name")->value;
    $members->{$name} = $id;
    $response->pop;
  } while ($response->next("member"));
}

my $editors = {};

if ($response->first("editor")) {
  do {
    $response->push;
    my $id = $response->value;
    my $name = $response->child("name")->value;
    $editors->{$name} = $id;
    $response->pop;
  } while ($response->next("editor"));
}

my $editorsline = join(", ", map { qq~<a href="userinfo?user=~ . escape_html($editors->{$_}) . qq~">$_</a>~ } sort { lc($a) cmp lc($b) } keys %$editors);

my $membersline = join(", ", map { qq~<a href="userinfo?user=~ . escape_html($members->{$_}) . qq~">$_</a>~ } sort { lc($a) cmp lc($b) } keys %$members);

$html .= qq~
<html>
<head>
<title>Folder Info</title>

<link rel=stylesheet type="text/css" href="ua.css">

</head>

<body>

<form method="post" action="infofile">
<input type="hidden" name="folder" value="$form{'folder'}">
<table width="100%" border="0" cellspacing="0" cellpadding="0" class="headers"><tr>
<td><table border="0" cellspacing="0" cellpadding="0" class="title"><tr>
<td colspan="2">Folder information for $foldername</td>
</tr>~;

if ($editorsline || $membersline) {
  if ($editorsline) {
    my $title = (scalar(keys %$editors) == 1)?"Editor":"Editors";
    $html .= qq~<tr><td>$title:&nbsp;</td><td class="htext">$editorsline</td></tr>~;
  }
  if ($membersline) {
    my $title = (scalar(keys %$members) == 1)?"Member":"Members";
    $html .= qq~<tr><td>$title:&nbsp;</td><td class="htext">$membersline</td></tr>~;
  }
}

$html .= qq~</table></td>
</tr>~;

if (canEditInfo($userid)) {
  $html .= qq~<tr><td><textarea name="infofile" rows="10" wrap="virtual" cols="80" class="messagemono">~ . escape_html($info, 0, 1) . qq~\n</textarea></td></tr><tr>\n<td class="buttonhole"><input type="submit" name="Submit" value="Change entry" class="button"></td>\n</tr>~;
} else {
  $html .= qq~<tr><td><div class="message">~ . escape_html($info, 1) . qq~</div></td></tr>~ if ($info =~ /\S/);
}

$html .= qq~</table>
</form>

</body>
</html>
~;

return $html;

}

###

sub canEditInfo {

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

