### uaHTTP display folder functions ###

### Functions ###

sub display_announcements {

my ($handle, $content, $uaresponse, $username) = @_;
my ($response, $request, $html);

my @lines;

foreach $response ($handle->readAnnouncements) {

  my $line = "";

  my %element = $response->root->elements;

  foreach ($response->value) {

### USER

    m#^user_login$# && do {
	$line .= qq~<a href="userinfo?user=$element{'userid'}[0]" target="messages">$element{'username'}[0]</a> has logged in from ~;
	$line .= ($element{'location'}[0] || $element{'hostname'}[0] || $element{'address'}[0] || qq~[Unknown]~);
	last;
    };

    m#^user_login_denied$# && do {
	$line .= qq~<a href="userinfo?user=$element{'userid'}[0]" target="messages">$element{'username'}[0]</a> has been denied login from ~;
	$line .= ($element{'location'}[0] || $element{'hostname'}[0] || $element{'address'}[0] || qq~[Unknown]~);
	last;
    };

    m#^user_login_invalid$# && do {
	$line .= qq~<a href="userinfo?user=$element{'userid'}[0]" target="messages">$element{'username'}[0]</a> has failed to login from ~;
	$line .= ($element{'location'}[0] || $element{'hostname'}[0] || $element{'address'}[0] || qq~[Unknown]~);
	last;
    };

    m#^user_logout$# && do {
	$line .= qq~<a href="userinfo?user=$element{'userid'}[0]" target="messages">$element{'username'}[0]</a> has ~;

	if ($element{'force'}[0]) {
	  $line .= qq~been logged out~;
	  $line .= qq~by $element{'byname'}[0]~ unless ($element{'byname'}[0] eq "");
	} elsif ($element{'lost'}[0] == 1) {
	  $line .= qq~lost connexion~;
	} else {
	  $line .= qq~logged out~;
 	}

	$line .= qq~ ($element{'text'}[0])~ unless ($element{'text'}[0] eq "");
	last;
    };

    m#^user_status$# && do {
	if (exists $element{'status'}) {
	  my $possesive = qw/his his her its/[$element{'gender'}[0] || 3];
	  $line .= qq~<a href="userinfo?user=$element{'userid'}[0]" target="messages">$element{'username'}[0]</a> has turned $possesive pager ~;
	  $line .= ($element{'status'}[0] & Login('LOGIN_BUSY'))?qq~off~:qq~on~;
	} else {
	  $line .= qq~<a href="userinfo?user=$element{'userid'}[0]" target="messages">$element{'username'}[0]</a> has changed message ~;
	}
	$line .= qq~ (~ . escape_html($element{'statusmsg'}[0]) . qq~)~ unless ($element{'statusmsg'}[0] eq "");
	last;
    };

    m#^user_add$# && do {
	$line .= qq~User <a href="userinfo?user=$element{'userid'}[0]" target="messages">$element{'username'}[0]</a> created~;
	$line .= qq~by $element{'byname'}[0]~ unless ($element{'byname'}[0] eq "");
	last;
    };

    m#^user_delete$# && do {
	$line .= qq~User <a href="userinfo?user=$element{'userid'}[0]" target="messages">$element{'username'}[0]</a> deleted~;
	$line .= qq~by $element{'byname'}[0]~ unless ($element{'byname'}[0] eq "");
	last;
    };

    m#^user_page$# && do {

        my $anmessage = escape_html($element{'text'}[0], 1, 1);

	if ($element{'_seen'}[0]) {
	  $line .= qq~You were paged by <a href="userinfo?user=$element{'fromid'}[0]" target="messages">$element{'fromname'}[0]</a>: $anmessage~;
	} else {
          my $jsmessage = $element{'text'}[0];
          $jsmessage = escape_html($jsmessage, 1);
	  $jsmessage =~ s/\n/\\n/g;
	  $jsmessage =~ s/'/&#039;/g;

	  $line .= <<HTML;
<a href="userinfo?user=$element{'fromid'}[0]" target="messages">$element{'fromname'}[0]</a> is paging you: $anmessage
<script language="JavaScript">
<!--
pageMessage('$element{'fromname'}[0]', '$jsmessage');
// -->
</script>
HTML
	}
	last;
    };


### MESSAGE

    m#^message_add$# && do {
	$line .= qq~Message <a href="showmessage?folder=$element{'folderid'}[0]&message=$element{'messageid'}[0]" onClick="updateMessageList('$element{'messageid'}[0]', '$element{'folderid'}[0]')" target="messages">$element{'messageid'}[0]</a> has been posted in $element{'foldername'}[0] by <a href="userinfo?user=$element{'fromid'}[0]" target="messages">$element{'fromname'}[0]</a>~;
        $line .= qq~ (~ . escape_html($element{'subject'}[0]) . qq~)~ unless ($element{'subject'}[0] eq "");
        if ($element{'marktype'}[0]) {
          $line .= qq~ [Caught-up]~;
        } elsif ($element{'marked'}[0]) {
          $line .= qq~ [Marked read]~;
        }
	last;
    };

    m#^message_(delete|move)$# && do {
	my $nummsgs = $element{'num${1}d'}[0];
	my $type    = $element{'${1}type'}[0];

	if ($type != 2 || $nummsgs > 1) {
	  if ($type == 2) {
	    $line .= qq~$nummsgs ~;
	    $line .= ($nummsgs == 1)?qq~reply~:qq~replies~;
	    $line .= qq~ to message $element{'messageid'}[0]~;
	  } else {
	    $line .= qq~Message $element{'messageid'}[0]~;
	    if ($nummsgs > 1) {
	      $line .= qq~ and ~;
	      $line .= $nummsgs - 1;
	      $line .= ($nummsgs == 2)?qq~reply~:qq~replies~;
	    }
	  }

	  if ($1 eq "delete") {
	    $line .= qq~ deleted from $element{'foldername'}[0]~;
	  } else {
	    $line .= qq~ moved from $element{'foldername'}[0] to $element{'movename'}[0]~;
	  }

	  $line .= qq~ by $element{'byname'}[0]~ unless ($element{'byname'}[0] eq "");
	}
	last;
    };

    m#^message_edit$# && do {
	$line .= qq~Message <a href="showmessage?folder=$element{'folderid'}[0]&message=$element{'messageid'}[0]" onClick="updateMessageList('$element{'messageid'}[0]', '$element{'folderid'}[0]')" target="messages">$element{'messageid'}[0]</a> in $element{'foldername'}[0] has been edited~;
	$line .= qq~ by $element{'byname'}[0]~ unless ($element{'byname'}[0] eq "");
	last;
    };

    m#^message_vote$# && do {
	# IGNORE MESSAGE VOTE
	last;
    };

### SYSTEM

    m#^system_write$# && do {
	$line .= qq~System write complete ($element{'writetime'}[0] ms)~;
	last;
    };

    m#^system_message$# && do {
	$line .= qq~System message from $element{'fromname'}[0]:<br>~;
	$line .= escape_html($element{'text'}[0], 1, 0);
	last;
    };

    m#^system_shutdown$# && do {
	$line .= qq~Server shutdown~;
	$line .= qq~ by $element{'fromname'}[0]~ unless ($element{'fromname'}[0] eq "");
	$line .= ($element{'interval'}[0])?qq~ in $element{'interval'}[0] seconds~:qq~ now~;
	$line .= qq~<br>~ . escape_html($element{'text'}[0], 1, 0) unless ($element{'text'}[0] eq "");
	last;
    };

    m#^system_reload$# && do {
	$line .= qq~System library reload complete ($element{'reloadtime'}[0] ms)~;
	last;
    };

    m#^system_maintenance$# && do {
	# IGNORE SYSTEM MAINTENANCE
	last;
    };

### FOLDER

    m#^folder_add$# && do {
	$line .= qq~Folder $element{'foldername'}[0] has been created~;
	$line .= qq~by $element{'byname'}[0]~ unless ($element{'byname'}[0] eq "");
        $line .= qq~. <a href="subscribe?folder=$element{'folderid'}[0]&subscribe=1" target="messagelist">Subscribe?</a>~;
	last;
    };

    m#^folder_edit$# && do {
	$line .= qq~Folder $element{'foldername'}[0] has been edited~;
	$line .= qq~by $element{'byname'}[0]~ unless ($element{'byname'}[0] eq "");
	last;
    };

    m#^folder_delete$# && do {
	$line .= qq~Folder $element{'foldername'}[0] has been deleted~;
	$line .= qq~by $element{'byname'}[0]~ unless ($element{'byname'}[0] eq "");
	last;
    };

    m#^folder_(?:subscribe|unsubscribe)$# && do {
	my $by = ($element{'byname'}[0] ne "");

	$line .= qq~$element{'username'}[0] has ~;
	$line .= qq~been ~ if ($by);

	if (m#^folder_unsubscribe$#) {
	  $line .= qq~unsubscribed from ~;
	} elsif ($element{'subtype'}[0] == 1) {
	  $line .= qq~subscribed to ~;
	} elsif ($element{'subtype'}[0] == 2) {
	  $line .= ($by)?qq~made ~:qq~become ~;
	  $line .= qq~a member of ~;
	} elsif ($element{'subtype'}[0] == 3) {
	  $line .= ($by)?qq~made ~:qq~become ~;
	  $line .= qq~an editor of ~;
	}

	$line .= $element{'foldername'}[0];
	$line .= qq~ by $element{'byname'}[0]~ if ($by);
	last;
    };

### CONNECTION

    m#^connection_# && do {
	# IGNORE CONNECTION MESSAGES
	last;
    };

### CHANNEL

    m#^channel_# && do {
	# IGNORE CHANNEL MESSAGES
	last;
    };

### OTHER

			   do {
	$line .= qq~Announce: $_~
    };

  }

  my $time = join(":", map { substr("00$_", -2) } (localtime($element{'announcetime'}[0]))[2, 1, 0]);

  if ($element{'_seen'}[0]) {
    unshift(@lines, "[$time] $line");
  } else {
    unshift(@lines, "[$time] <b>$line</b>");
  }

  $response->DESTROY;

}

my $lastupdate = join(":", map { substr("00$_", -2) } (localtime)[2, 1, 0]);

$html .= q~
<html>
<head>
<title>Announcements</title>
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

<script language="JavaScript">
<!--

var xuserpass = "";
var xpagetextpass = "";

isOpera = ( navigator.userAgent.search(/Opera/)   > -1 );
isIE    = ( navigator.userAgent.search(/MSIE/)    > -1 ) && (! isOpera);
isNS    = ( navigator.userAgent.search(/Mozilla/) > -1 ) && (! ( isOpera || isIE) );

function pageMessage(xuser, xpagetext) {

xpagetext = xpagetext.replace(/\n+$/, "");
xpagetext = xpagetext.replace(/^\n+/, "");

if (isIE)    pageMessageIE(xuser, xpagetext);
if (isOpera) pageMessageNSOpera(xuser, xpagetext);
if (isNS)    pageMessageNSOpera(xuser, xpagetext);

}

function pageMessageIE(xuser, xpagetext) {

window.showModalDialog("pagereply.html", new Array(xuser, xpagetext), "dialogHeight: 300px; dialogWidth: 620px; center: yes; help: no; resizable: yes; status: no; edge: raised;");

}

function pageMessageNSOpera(xuser, xpagetext) {

xuserpass = xuser;
xpagetextpass = xpagetext;

window.open("pagereplyns.html", "_blank", "height=300,width=620,location=no,menubar=no,status=no,toolbar=no,directories=no,resizeable=yes,scrollbars=yes");

}

// -->
</script>

</head>

<body class="announce">

<div class="lastupdate">Last updated: ~ . $lastupdate . q~</div>

<nobr>
~;

$html .= (scalar @lines)?join("<br>\n", @lines):"No recent announcements";

$html .= qq~
</nobr>
</body>
</html>
~;

return $html;

}

###
1;
