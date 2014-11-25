### uaHTTP display user info functions ###

### Functions ###

sub display_userinfo {

my ($handle, $content, $uaresponse, $username) = @_;
my ($response, $request, $html);

my %form = %$content;

my $canonname = $uaresponse->child("name")->value;
my $userid    = $uaresponse->first("userid")->value;

$form{user} = $userid unless defined($form{user});

$request = clean EDF::Object("request", \"user_list");
#$request->addChild("searchtype", 3);
$request->addChild("userid", $form{user});

$response = $handle->request($request);

$request->DESTROY;

die "User #$form{user} does not exist\n" if ($response->value eq "user_not_exist"); 

unless ($response->value eq "user_list") {
  die "Unknown response: " . $response->value . "\n";
}

my $systemtime = $response->child("systemtime")?$response->value:0;
my %user = $response->first("user")->elements;
my %login = $response->child("login") && $response->elements;

my $status = $login{'status'}[0];

my ($accesslevel) = {
	LEVEL_NONE	=> "None",
	LEVEL_GUEST	=> "Guest",
	LEVEL_MESSAGES	=> "Messages",
	LEVEL_EDITOR	=> "Editor",
	LEVEL_WITNESS	=> "Witness",
	LEVEL_SYSOP	=> "SysOp",
  }->{ Access($user{'accesslevel'}[0]) };

if ($user{'usertype'} == 1) {
  $accesslevel = "Agent";
}

my ($sex) = {
	GENDER_PERSON	=> "Person",
	GENDER_MALE	=> "Male",
	GENDER_FEMALE	=> "Female",
	GENDER_NONE	=> "None",
  }->{ Sex( defined($user{'gender'}[0])?$user{'gender'}[0]:3 ) };

$html .= qq~
<html>
<head>
<title>User Info for $user{"name"}[0]</title>

<link rel=stylesheet type="text/css" href="ua.css">

</head>

<body>

<form method="post" action="description">
<table width="100%" border="0" cellspacing="0" cellpadding="0" class="headers"><tr>
<td><table border="0" cellspacing="0" cellpadding="0" class="title"><tr>
<td colspan="2">User information for $user{'name'}[0]</td>
</tr><tr>
<td>ID:&nbsp;</td><td class="htext">$form{'user'}</td>
</tr><tr>
<td>Access level:&nbsp;</td><td class="htext">$accesslevel</td>
</tr><tr>
<td>Sex:&nbsp;</td><td class="htext">$sex</td>
</tr></table></td>
</tr>~;

if ($form{user} == $userid) {
  $html .= qq~<tr><td><textarea name="description" rows="10" wrap="virtual" cols="80" class="messagemono">~ . escape_html($user{"description"}[0], 0, 1) . qq~\n</textarea></td></tr>~;
  $html .= qq~<tr>\n<td class="buttonhole"><input type="submit" name="Submit" value="Change entry" class="button"></td>\n</tr>~;
} else {
  $html .= qq~ <tr><td><div class="messagemono">~ . escape_html($user{"description"}[0], 1) . qq~</div></td></tr>~ if ($user{"description"} =~ /\S/);
}

$html .= qq~<tr>
<td><table border="0" cellspacing="0" cellpadding="0" class="title"><tr>
<td colspan="2">~;

$html .= ($status)?'Current':'Last';

$html .= qq~ login</td></tr>~;

$html .= qq~<tr><td>On:&nbsp;</td><td class="htext">~ . shortParseDate($login{timeon}[0]) . qq~</td></tr>~;
$html .= qq~<tr><td>Off:&nbsp;</td><td class="htext">~ . shortParseDate($login{timeoff}[0]) . qq~</td></tr>~ unless ($status);
$html .= qq~<tr><td>Busy:&nbsp;</td><td class="htext">~ . hoursminutes($systemtime - $login{timebusy}[0]) . qq~</td></tr>~ if ($status & Login(LOGIN_BUSY));
$html .= qq~<tr><td>Idle:&nbsp;</td><td class="htext">~ . hoursminutes($systemtime - $login{timeidle}[0]) . qq~</td></tr>~ if ($status & Login(LOGIN_IDLE));
$html .= qq~<tr><td>From:&nbsp;</td><td class="htext">~ . escape_html($login{location}[0] || '[Unknown]') . qq~</td></tr>~;

$html .= qq~<tr><td colspan="2"><br>Page <a href="displaypage?user=$form{'user'}">$user{'name'}[0]</a></td></tr>~ if ($status);

$html .= qq~
</table></td>
</tr></table>

</form>
</body>
</html>
~;

return $html;

}

###
1;

