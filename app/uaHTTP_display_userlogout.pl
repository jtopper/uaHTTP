### uaHTTP display user info functions ###

### Functions ###

sub display_userlogout {

my ($handle, $content, $uaresponse, $username) = @_;
my ($response, $request, $html);

my %form = %$content;

my $canonname = $uaresponse->child("name")->value;
my $userid    = $uaresponse->first("userid")->value;

$html .= qq~
<html>
<head>
<title>User Logout for $canonname</title>

<link rel=stylesheet type="text/css" href="ua.css">

</head>

<body>

<div align="center">
<img src="$IMAGEDIR/uahttp.gif" width="200" height="206" alt=" uaHTTP ">
<p>User $canonname has logged out from UA.</p>
<p>Close your browser to clear your username and password from its memory.</p>
<p><a href="./">Relogin to UA</a>
</div>

</body>
</html>
~;

$request = clean EDF::Object("request", \"user_logout");
$request->addChild("text", \"$form{'message'}") if ($form{'message'});
$response = $handle->request($request);
$request->DESTROY;

return $html;

}

###
1;

