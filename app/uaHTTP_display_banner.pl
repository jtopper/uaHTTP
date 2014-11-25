### uaHTTP display banner functions ###

### Functions ###

sub display_banner {

my ($handle, $content, $uaresponse, $username) = @_;
my ($response, $request, $html);

my %form = %$content;

my $canonname = $uaresponse->child("name")->value;
my $userid    = $uaresponse->first("userid")->value;

$request = clean EDF::Object("request", \"system_list");
$response = $handle->request($request);

$request->DESTROY;

unless ($response->value eq "system_list") {
  die "Unknown response: " . $response->value . "\n";
}

my $banner = $response->child("banner")?$response->value:"";

$html .= qq~
<html>
<head>
<title>UA</title>

<link rel=stylesheet type="text/css" href="ua.css">

</head>

<body>

<table width="100%" border="0" cellspacing="0" cellpadding="0" class="headers"><tr>
<td>System Banner for UA~;

$html .= qq~</td>
</tr><tr>
<td><div class="message"><pre style="font-size: 80%">~;
$html .= escape_html($banner, 1);
$html .= qq~</pre></div></td>
</tr></table>

</body>
</html>
~;

return $html;

}

###
1;

