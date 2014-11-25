### uaHTTP display folder functions ###

### Functions ###

sub display_folder {

my ($handle, $content, $uaresponse, $username) = @_;
my ($response, $request, $html);
my (@messages, $first_message);

local %form = %$content;

my $canonname = $uaresponse->child("name")->value;
my $userid    = $uaresponse->first("userid")->value;

defined($form{folder}) || die "No folder passed to display_folder\n";

$request = clean EDF::Object("request", \"folder_list");
$request->addChild("searchtype", 3);
$request->addChild("folderid", $form{folder});

$response = $handle->request($request);

$request->DESTROY;

unless ($response->value eq "folder_list") {
  die "Unknown response: " . $response->value . "\n";
}

$response->child("folder") || die "No such folder (#$form{folder})\n";

$folderid   = $response->value;

$nummsgs    = $response->child("nummsgs")?$response->value:0;
$unread     = $response->first("unread")?$response->value:0;
$subscribed = $response->first("subtype")?$response->value:0;
$accessmode = $response->first("accessmode")->value;
$response->parent;

# Set default view to be unread messages unless there are none
$form{messages} = ($unread)?"unread":"all" unless ($form{messages});

{
  my $request = clean EDF::Object("request", \"message_list");
  $request->addChild("searchtype", 1);
  $request->addChild("folderid", $form{folder});

  if ($accessmode & Folder(FOLDER_PRIVATE)) {
    $request->add("or");
    $request->addChild("toid", $userid);
    $request->addChild("fromid", $userid);
    $request->parent;
  }

  my $response = $handle->request($request);
  $request->DESTROY;

  unless ($response->value eq "message_list") {
    die "Unknown response: " . $response->value . "\n";
  }

  @messages = get_messages($response);

  $first_message = (keys %{$messages[0]})[0] if ($unread && ($form{messages} eq "unread"));

  $response->DESTROY;

}

$html .= qq~
<html>
<head>
<title>Message list</title>

<link rel=stylesheet type="text/css" href="ua.css">

<script language="Javascript">
<!--

var omess;
var isIE = document.all;

function QueryString(key) {
  var value = null;
  for (var i=0;i<QueryString.keys.length;i++) {
    if (QueryString.keys[i]==key) {
      value = QueryString.values[i];
      break;
    }
  }
  return value;
}

QueryString.keys = new Array();
QueryString.values = new Array();

function QueryString_Parse() {
  var query = self.location.search.substring(1);
  var pairs = query.split("&");

  for (var i=0;i<pairs.length;i++) {
    var pos = pairs[i].indexOf('=');
    if (pos >= 0) {
      var argname = pairs[i].substring(0,pos);
      var value = pairs[i].substring(pos+1);
      QueryString.keys[QueryString.keys.length] = argname;
      QueryString.values[QueryString.values.length] = value;		
    }
  }
}

QueryString_Parse();

function openMessage(mid, findmess, openmess) {

  if (parent.messages) {
    if (mid == -1) {
      parent.messages.location = "blank.html";
      return;
    } else if (mid == -2) {
      parent.messages.location = "folderinfo?folder=$form{folder}";
      return;
    } else if (openmess) {
      parent.messages.location = "showmessage?folder=$form{folder}&amp;message=" + mid;
    }
  }

  if (! document.images["mess" + mid]) {
    if ( (QueryString("folder") != '$form{folder}') || (QueryString("message") != mid) || (QueryString("messages") != "all") ) {
      self.location = "showfolder?messages=all&amp;folder=$form{folder}&amp;message=" + mid;
    }
    return;
  }

  if (omess) { document.images["mess" + omess].src = "$IMAGEDIR/rm.gif"; }
  document.images["mess" + mid].src = "$IMAGEDIR/om.gif";
  omess = mid;

  document.images["mess" + mid].parentElement.className = "ra";

  if (isIE && findmess) {
    document.images["mess" + mid].scrollIntoView(true);
    window.scrollBy(0, -26);
  }

}

function updateFolderList(fid) {

  parent.folders.openFolder(fid);

}

// -->
</script>

</head>

~;

if ($form{message}) {
  $html .= qq~<body onLoad="openMessage($form{message}, true, false)">~
} elsif ($first_message) {
  $html .= qq~<body onLoad="openMessage($first_message, false, true)">~;
} elsif ($form{info}) {
  $html .= qq~<body onLoad="openMessage(-2, false, false)">~;
} elsif ($form{noload}) {
  $html .= qq~<body>~;
} else {
  $html .= qq~<body onLoad="openMessage(-1, false, false)">~;
}
$html .= qq~

<table width="100%" border="0" cellspacing="0" cellpadding="0" class="headers"><tr>
<td>~;

my $folderimage = "of";
$folderimage .= "u" unless ($subscribed);
$folderimage .= "e" if ($EDITOR{$userid}{$form{'folder'}});

$html .= qq~<img src="$IMAGEDIR/$folderimage.gif" width="16" height="13" alt="" border="0">&nbsp;~;

$response->push;
my @trail = ();
if ($response->root->child("pathid")) {

  do {

    $response->push;

    my $id   = $response->value;
    my $name = $response->child("foldername")->value;

    unshift(@trail, [$id, $name]);

    $response->pop;

  } while ($response->child("pathid"));

  $response->parent;

}
$response->pop;

foreach $crumb (@trail) {
  my($id, $name) = @$crumb;
  $html .= qq~<a href="showfolder?folder=$id" onClick="updateFolderList($id)">$name</a> : ~;
}

my $foldername = $response->child("name")->value;
$html .= $foldername;

#$response->push;
#$info = $response->next("info") && $response->child("text") && $response->value;
#$response->pop;

$nummsgs .= ($nummsgs == 1)?"&nbsp;Message":"&nbsp;Messages";

$html .= qq~</td>
<td align=right><a href="showfolder?folder=$form{folder}&amp;messages=all">$nummsgs</a> / <a href="showfolder?folder=$form{folder}&amp;messages=unread">$unread&nbsp;Unread</a> / <a href="postmessage?folder=$form{folder}" target="messages"><img src="$IMAGEDIR/post.gif" width="16" height="13" alt="" border="0">&nbsp;Post</a></td>
</tr></table>

<br>

<table cellpadding="0" cellspacing="0" border="0" width="100%">
~;

$response->DESTROY;

foreach $element (@messages) {
  my($id, $hash) = each %$element;
#  $html .= "$id : " . join(" - ", keys %$hash) . "\n";

  $html .= qq~<tr><td class="nest">~;

  if ($hash->{depth}) {
    if ($hash->{depth} < 11) {
    $html .= qq~<img src="$IMAGEDIR/bu~ .
      $hash->{depth} .
      qq~.gif" height="13" width="~ .
      16 * $hash->{depth} .
      qq~" border="0" alt="~ .
      join(" ", ("*") x $hash->{depth}) .
      qq~">~;
  } else {
    $html .= qq~<img src="$IMAGEDIR/bu10.gif" height="13" width="160" border="0" alt="* * * * * * * * * *">(~ . $hash->{depth} . qq~)~;
  }
}

$html .= qq~<a href="showmessage?folder=$folderid&amp;message=$id" target="messages" class="~ .
      ($hash->{read}[0]?"ra":"un") .
      qq~" onClick="openMessage($id, false)"><img src="$IMAGEDIR/~ .
      ($hash->{read}[0]?"rm":"cm") .
      qq~.gif" height="13" width="16" border="0" name="mess$id" alt="*">~ .
      qq~ <span class="subj">~ . parse_colours(escape_html($hash->{subject}[0])) .
      qq~</span></a> <span class="auth">(~ . $hash->{fromname}[0] .
      qq~)</span> <span class="date">~ . shortParseDate($hash->{date}[0]) .
      qq~</span>~;

$html .= qq~</td></tr>\n~;

}

$html .= "</table>\n";

$html .= qq~
<br>
<table width="100%" border="0" cellspacing="0" cellpadding="0" class="headers"><tr>
~;

if ($EDITOR{$userid}{$form{'folder'}}) { # Cannot unsubscribe if editor
  $html .= qq~<td>&nbsp;</td>~;
} elsif ($subscribed) {
  $html .= qq~<td><a href="subscribe?folder=$form{folder}&amp;subscribe=0" onclick="return confirm('Do you want to unsubscribe from $foldername?')"><img src="$IMAGEDIR/cfu.gif" width="16" height="13" alt="" border="0">&nbsp;Unsubscribe</a></td>~;
} else {
  $html .= qq~<td><a href="subscribe?folder=$form{folder}&amp;subscribe=1"><img src="$IMAGEDIR/cf.gif" width="16" height="13" alt="" border="0">&nbsp;Subscribe</a></td>~;
}

$html .= qq~
<td align="right"><a href="catchup?folder=$form{folder}">Catch Up All</a> / <a href="folderinfo?folder=$form{folder}" target="messages"><img src="$IMAGEDIR/i.gif" width="16" height="13" alt="" border="0">&nbsp;Info</a></td>
</tr></table>

</body>
</html>
~;

return $html;

}

###
1;
