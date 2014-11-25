### uaHTTP display folders functions ###

### Functions ###

sub display_folders {

my ($handle, $content, $uaresponse, $username) = @_;
my ($response, $request, $html);

my %form = %$content;

my $canonname = $uaresponse->child("name")->value;
my $userid    = $uaresponse->first("userid")->value;

$request = clean EDF::Object("request", \"user_list");
$request->addChild("searchtype", 1);
$request->addChild("userid", $userid);
$response = $handle->request($request);
$request->DESTROY;

my $busy = $response->child("user")->child("login")->child("status")->value & 2; # Login(LOGIN_BUSY)

my $setactive = ($form{setactive} eq "yes");

if ($busy && $setactive) {
  &unset_nocontact;
  $busy = 0;
}

$request = clean EDF::Object("request", \"folder_list");
$request->addChild("searchtype", 3);
$response = $handle->request($request);
$request->DESTROY;

unless ($response->value eq "folder_list") {
  die "Unknown response: " . $response->value . "\n";
}

my @list = get_folders($response);

my $numfolders = $response->root->child("numfolders")->value;

$response->DESTROY;

my $list;
my $key;
my %table = ();
my $ref;
my @depth = ();
my $numsubscribe = 0;
my $numunread = 0;

my %dropdown = ('' => '<option value="0" class="fs"> ');

my $all    = ($form{folders}  eq "all");
my $unread = ($form{unread}   eq "yes");
my $thread = ($form{threaded} eq "yes");

foreach $list (@list) {
  foreach $key (keys %$list) {

    my $sub = %$list->{$key}{subtype}[0]?"fs":"fu";

    $dropdown{lc(%$list->{$key}{name}[0])} = qq~<option value="$key" class="$sub">~ . %$list->{$key}{name}[0];

    next unless ($all || %$list->{$key}{subtype}[0]);

    $numsubscribe++ if (%$list->{$key}{subtype}[0]);

    next unless ((! $unread) || %$list->{$key}{unread}[0]);

    my $name  = %$list->{$key}{name}[0];
    my $depth = ($thread)?%$list->{$key}{depth}:0;

    my $output = qq~<tr><td class="fl">~;

    $output .= join("", 
      qq~<img src="$IMAGEDIR/bu$depth.gif" height="13" width="~,
      16 * $depth,
      qq~" border="0" alt="~,
      join(" ", ("*") x $depth),
      qq~">~,
    ) if ($depth);

    my $folderimage = "cf";
    $folderimage .= "u" unless (%$list->{$key}{subtype}[0]);
    $folderimage .= "e" if ($EDITOR{$userid}{$key});

    $output .= join("", 

      qq~<a href="showfolder?folder=$key" target="messagelist" class="~,
      %$list->{$key}{unread}[0]?"un":"ra",
      qq~" onClick="openFolder($key)"><img src="$IMAGEDIR/$folderimage.gif" height="13" width="16" border="0" name="folder$key" alt="*"> $name~,
    );

    if (%$list->{$key}{unread}[0]) {
      $output .= qq~ [~ . %$list->{$key}{unread}[0] . qq~]~;
      $numunread++;
    }

    $output .= qq~</a></td></tr>~;

    if ($depth == 0) {
      $table{$name} = $depth[$depth] = { output => $output, children => [] };
    } else {
      push(@{ %{$depth[$depth - 1]}->{children} }, $depth[$depth] = { name => $name, output => $output, children => [] });
    }

  }
}

$numfolders .= ($numfolders == 1)?"&nbsp;Folder":"&nbsp;Folders";

my $dropdown = join("\n", map { $dropdown{$_} } sort keys %dropdown);

$html = qq~
<html>
<head>
<title>Folder list</title>

<link rel=stylesheet type="text/css" href="ua.css">

<script language="Javascript">
<!--

var ofolder;
var cfimage;
var ofimage;

function openFolder(fid) {

  if (document.images["folder" + fid]) {

    if (document.images["folder" + fid].src.indexOf("u.gif") > -1) {
      ofimage = "ofu";
    } else if (document.images["folder" + fid].src.indexOf("e.gif") > -1) {
      ofimage = "ofe";
    } else {
      ofimage = "of";
    }

    document.images["folder" + fid].src = "$IMAGEDIR/" + ofimage + ".gif";

  }

  if (ofolder != fid) {
    closeFolder(fid);
  }

}

function closeFolder(fid) {

  if (ofolder && (document.images["folder" + ofolder]) ) {

    if (document.images["folder" + ofolder].src.indexOf("u.gif") > -1) {
      cfimage = "cfu";
    } else if (document.images["folder" + ofolder].src.indexOf("e.gif") > -1) {
      cfimage = "cfe";
    } else {
      cfimage = "cf";
    }

    document.images["folder" + ofolder].src = "$IMAGEDIR/" + cfimage + ".gif"; 

  }

  ofolder = fid;

}

function logoutMessage() {

var message = window.prompt("Logout message (Escape to cancel):", "");

if (message == null) return;

window.top.location.replace("userlogout?message=" + message);

}

function changeMessage(askMessage) {

if (askMessage) {
  var message = window.prompt("Busy message (Escape to cancel):", "");
  if (message == null) return;
  location.replace('usermessage?threaded=$form{threaded}&amp;unread=$form{unread}&amp;folders=$form{folders}&amp;setactive=no&amp;message=' + message);
} else {
  location.replace('usermessage?threaded=$form{threaded}&amp;unread=$form{unread}&amp;folders=$form{folders}&amp;setactive=yes');
}

}

function jumpFolder(xfolder) {

if (xfolder > 0) {
  parent.frames['messagelist'].location.replace("showfolder?folder=" + xfolder + "&info=1");
  parent.frames['messagelist'].focus();
  openFolder(xfolder);
}

}

function checkQuery(xform) {

if (xform.elements['searchbox'].value.substring(0, 1) == "?") {
  xform.target ="messagelist";
}

return true;

}

// -->
</script>

</head>

<body>

<form target="messages" action="quickjump" method="post" onSubmit="checkQuery(this)">

<table width="100%" border="0" cellspacing="0" cellpadding="0" class="headers"><tr>
<td><a href="userinfo?user=$userid" target="messages">$canonname</a> /
<a href="userlogout" target="_top">Logout</a> /
<img src="$IMAGEDIR/lq.gif" title=" Logout with message " height="13" width="16" border="0" onclick="logoutMessage()" class="imgclick"> /
~;

if ($busy) {
  $html .= qq~<img src="$IMAGEDIR/b0.gif" title=" Go active " height="13" width="16" border="0" onclick="changeMessage(false)" class="imgclick"></td>~;
} else {
  $html .= qq~<img src="$IMAGEDIR/b1.gif" title=" Go busy " height="13" width="16" border="0" onclick="changeMessage(true)" class="imgclick"></td>~;
}

$html .= qq~
</tr><tr>
<td><a href="folders?threaded=$form{threaded}&amp;unread=no&amp;folders=all&amp;setactive=$form{setactive}">$numfolders</a> /
<a href="folders?threaded=$form{threaded}&amp;unread=no&amp;folders=subscribed&amp;setactive=$form{setactive}">$numsubscribe&nbsp;Subscribed</a> /
<a href="folders?threaded=$form{threaded}&amp;unread=yes&amp;folders=$form{folders}&amp;setactive=$form{setactive}">$numunread&nbsp;Unread</a></td>
</tr><tr>
<td>
~;

$html .= ($thread)?qq~<a href="folders?threaded=no&amp;unread=$form{unread}&amp;folders=$form{folders}">Unthreaded</a>~:qq~<a href="folders?threaded=yes&amp;unread=$form{unread}&amp;folders=$form{folders}">Threaded</a>~;

$html .= qq~
</td>
</tr></table>

<table border="0"><tr>
<td><img src="$IMAGEDIR/blank.gif" height="3" width="400" alt=" "></td>
</tr>
~;

foreach $name (sort { lc $a cmp lc $b } keys %table) {
  $html .= $table{$name}{output} . "\n";
  foreach $child (sort { lc(%$a->{name}) cmp lc(%$b->{name}) } @{$table{$name}{children}}) {
    $html .= %$child->{output} . "\n";
    foreach $child2 (sort { lc(%$a->{name}) cmp lc(%$b->{name}) } @{%$child->{children}}) {
      $html .= %$child2->{output} . "\n";
    }
  }
}

$html .= qq~<tr>
<td><img src="$IMAGEDIR/blank.gif" height="3" width="400" alt=" "></td>
</tr></table>

<table width="100%" border="0" cellspacing="0" cellpadding="0" class="headers"><tr>
<td><a href="wholist" target="messagelist" class="un" onClick="closeFolder()"><img src="$IMAGEDIR/wl.gif" height="13" width="16" border="0" name="wholist" alt=" ">&nbsp;Wholist</a></td>
</tr><tr>
<td><a href="search" target="messagelist" class="un" onClick="closeFolder()"><img src="$IMAGEDIR/find.gif" height="13" width="16" border="0" name="search" alt=" ">&nbsp;Search</a></td>
</tr><tr>
<td><a href="postmessage" target="messages" class="un" onClick="closeFolder()"><img src="$IMAGEDIR/post.gif" height="13" width="16" border="0" name="post" alt=" ">&nbsp;Post</a></td>
</tr><tr>
<td><a href="displaypage" target="messages" class="un" onClick="closeFolder()"><img src="$IMAGEDIR/page.gif" height="13" width="16" border="0" name="page" alt=" ">&nbsp;Page User</a></td>
</tr><!-- <tr>
<td><a href="options" target="messagelist" class="un" onClick="closeFolder()"><img src="$IMAGEDIR/op.gif" height="13" width="16" border="0" name="options" alt=" ">&nbsp;Configure</a></td>
</tr>--><tr>
<td style="border-top: 1px solid #000000"><input class="headinput" type="text" name="searchbox" value="" size="16" style="width: 100%"></td>
</tr><tr>
<td><select name="jumpfolder" class="fl" onChange="jumpFolder(this.options[this.selectedIndex].value)" style="width:100%" tabindex="0">$dropdown</select></td>
</tr></table>
</form>

</body>
</html>
~;

return $html;

}

###
1;
