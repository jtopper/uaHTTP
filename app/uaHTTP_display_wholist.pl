### uaHTTP display wholist functions ###

### Functions ###

sub display_wholist {

my ($handle, $content, $uaresponse, $username) = @_;
my ($response, $request, $html);

my %form = %$content;

my $canonname = $uaresponse->child("name")->value;
my $userid    = $uaresponse->first("userid")->value;

$html .= <<HTML;
<html>
<head>
<title>Wholist</title>
<link rel=stylesheet type="text/css" href="ua.css">

<script language="Javascript">
<!--

var isIE = document.all;

function showhide() {

if (isIE) {
  var wholist = document.all.wholist;
  for (xrow = 1; xrow < wholist.rows.length; xrow++) {
  var xhide = false;
    for (xcol = 1; xcol < 4; xcol++) {
      if (! document.all("check" + xcol).checked) {
        xhide = xhide || (wholist.rows(xrow).cells(xcol).innerHTML != "&nbsp;");
      }
    }
    wholist.rows(xrow).style.display = (xhide)?"none":"inline";
  }
}

}

// -->
</script>

</head>

<body>

<table border="0" class="wholist" cellspacing="0" id="wholist"><tr class="whotitle">
<td width="22">&nbsp;</td>

<!--[if IE ]>
<td width="22"><input type="checkbox" name="check1" checked onClick="showhide()"></td>
<td width="22"><input type="checkbox" name="check2" checked onClick="showhide()"></td>
<td width="22"><input type="checkbox" name="check3" checked onClick="showhide()"></td>
<![endif]-->
<![if ! IE ]>
<td width="22">&nbsp;</td>
<td width="22">&nbsp;</td>
<td width="22">&nbsp;</td>
<![endif]>

<td>~</td>
<td><a href="wholist?sort=by_time">Time</a></td>
<td>~</td>
<td><a href="wholist?sort=by_access">Access</td>
<td>~</td>
<td><a href="wholist?sort=by_name">Name</td>
<td>~</td>
<td><a href="wholist?sort=by_location">Location</td>
<td>~</td>
<td>Message</td>
</tr>

HTML

$request = clean EDF::Object("request", \"user_list");
$request->addChild("searchtype", 1);
$response = $handle->request($request);
$request->DESTROY;

unless ($response->value eq "user_list") {
  die "Unknown response: " . $response->value . "\n";
}

my $systemtime = $response->child("systemtime")?$response->value:0;
my $idletime   = $response->first("idletime")?$response->value:0;

$response->first("user");

my %wholist = ();
my $row;

do {

  $wholist{$response->value} = $row = {};

  $response->push;

  $row->{name}        = $response->child("name")?$response->value:undef;
  $row->{accesslevel} = Access($row->{accessnumber} = $response->first("accesslevel")?$response->value:0);
  $row->{accessname}  = $response->first("accessname")?$response->value:undef;
  $row->{sex}         = Sex($response->first("gender")?$response->value:3);
  $row->{usertype}    = $response->first("usertype")?$response->value:undef;

  $response->first("login");

  $row->{timeon}      = $response->child("timeon")?$response->value:0;
  $row->{timeidle}    = $response->first("timeidle")?$response->value:undef;
  $row->{timebusy}    = $response->first("timebusy")?$response->value:undef;
  $row->{message}     = $response->first("statusmsg")?$response->value:' ';
  $row->{status}      = $response->first("status")?$response->value:1;
  $row->{location}    = $response->first("location")?$response->value:'Unknown';

  $response->parent;

  $row->{userimage} = {
	GENDER_PERSON	=> "p",
	GENDER_MALE	=> "m",
	GENDER_FEMALE	=> "f",
	GENDER_NONE	=> "n",
  }->{$row->{sex}};

  ($row->{usercolour}, $row->{class}, $row->{trueaccessname}) = @{{
	LEVEL_NONE	=> [ "g", "none",     "None" ],
	LEVEL_GUEST	=> [ "g", "guest",    "Guest" ],
	LEVEL_MESSAGES	=> [ "g", "messages", "Messages" ],
	LEVEL_EDITOR	=> [ "m", "editor",   "Editor" ],
	LEVEL_WITNESS	=> [ "y", "witness",  "Witness" ],
	LEVEL_SYSOP	=> [ "r", "sysop",    "SysOp" ],
  }->{$row->{accesslevel}}};

  $row->{accessname} ||= $row->{trueaccessname};

  if ($row->{usertype} == 1) { # Agent
    $row->{userimage}  = "a";
    $row->{usercolour} = "b";
    $row->{accessname} = "Agent";
    $row->{class}      = "agent";
  }

#  $row->{usercolour} = "b"; #All users in blue

#  $wholist{$row->{name}} = $row;

  $response->pop;

} while $response->next("user");

sub by_name { lc $wholist{$a}{name} cmp lc $wholist{$b}{name} }
sub by_time { $wholist{$a}{timeon} <=> $wholist{$b}{timeon} || &by_name}
sub by_access { $wholist{$b}{accessnumber} <=> $wholist{$a}{accessnumber} || &by_time}
sub by_location { $wholist{$a}{location} cmp $wholist{$b}{location} || &by_time}

my $sorting = $form{sort} || "by_time";

foreach $key (sort $sorting keys %wholist) {

  $html .= qq~
<tr class="who$wholist{$key}{class}">
<td><img src="$IMAGEDIR/who/$wholist{$key}{userimage}$wholist{$key}{usercolour}.gif" width="22" height="15" alt=""></td>
~;

  $html .= ($wholist{$key}{status} & Login(LOGIN_IDLE))?qq~<td><img src="$IMAGEDIR/who/idle.gif" width="22" height="15" alt="Idle: ~ . hoursminutes($systemtime - $wholist{$key}{timeidle}) . qq~"></td>~:'<td>&nbsp;</td>';
  $html .= ($wholist{$key}{status} & Login(LOGIN_BUSY))?qq~<td><img src="$IMAGEDIR/who/busy.gif" width="22" height="15" alt="Busy: ~ . hoursminutes($systemtime - $wholist{$key}{timebusy}) . qq~"></td>~:'<td>&nbsp;</td>';
  $html .= ($wholist{$key}{status} & Login(LOGIN_TALKING))?qq~<td><img src="$IMAGEDIR/who/talk.gif" width="22" height="15" alt="Talking"></td>~:'<td>&nbsp;</td>';

  $html .= qq~
<td>&nbsp;</td>
<td class="time">~ . hoursminutes($systemtime - $wholist{$key}{timeon}) . qq~</td>
<td>&nbsp;</td>
<td title="~ . $wholist{$key}{trueaccessname} . qq~">$wholist{$key}{accessname}</td>
<td>&nbsp;</td>
<td><a href="userinfo?user=$key" target="messages">$wholist{$key}{name}</a></td>
<td>&nbsp;</td>
<td>$wholist{$key}{location}</td>
<td>&nbsp;</td>
<td>~ . escape_html($wholist{$key}{message}) . qq~</td>
</tr>
~;

}

$html .= qq~

</table>

<img src="$IMAGEDIR/blank.gif" height="1" width="1280" alt=" ">

</body>
</html>
~;

return $html;

}

###

sub hoursminutes {

my $seconds = shift;

my($hours, $mins);

$seconds -=  3600 * ($hours = int($seconds / 3600));
$seconds -=    60 * ($mins  = int($seconds / 60));

$hours ||= "0";
$mins    = substr("00$mins", -2); 

return "$hours:$mins";

}

###
1;

