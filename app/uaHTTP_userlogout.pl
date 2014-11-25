### uaHTTP logout user functions ###

### Functions ###

sub user_logout {

my ($handle, $content, $uaresponse, $username) = @_;
my ($response, $request, $html);

my %form = %$content;

my $canonname = $uaresponse->child("name")->value;
my $userid    = $uaresponse->first("userid")->value;

my @pages;

foreach $response ($handle->readAnnouncements) {

  my $line = "";

  my %element = $response->root->elements;

  if ($response->value =~ m#^user_page$#) {

    unless ($element{'_seen'}[0]) {

      my $time = join(":", map { substr("00$_", -2) } (localtime($element{'announcetime'}[0]))[2, 1, 0]);

      push(@pages, [ $element{'fromid'}[0], $element{'fromname'}[0], escape_html($element{'text'}[0], 1), $time ]);

    }

  }

  $response->DESTROY;

}

my $pages = "";

foreach my $page (@pages) {
  $pages .= qq~<tr><td>Page sent at ~ . $page->[3] . qq~ by ~ . $page->[1] . qq~:<div class="message">~ . $page->[2] . qq~</div></td></tr>\n~;
}

my $nopages = (@pages == 1)?"page was":"pages were";


$html .= qq~
<html>
<head>
<title>User Logout for $canonname</title>

<link rel=stylesheet type="text/css" href="ua.css">

</head>

<body>

<div align="center">
<img src="$IMAGEDIR/uahttp.gif" width="200" height="206" alt=" uaHTTP ">
<p>You have logged out from UA.</p>
~;

$html .= qq~

<table width="80%" border="0" cellspacing="0" cellpadding="0" class="headers"><tr>
<td>The following $nopages still pending:<hr></td>
</tr>$pages</table>

~ if ($pages);

$html .= qq~
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

$handle->close();

return $html;

}

###
1;

