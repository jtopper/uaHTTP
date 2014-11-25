### uaHTTP general functions ###

### Constants ###

$SERVER_ROOT = './root/';

### Functions ###

sub pretty {

my $string = shift;
$string =~ s#([^\\]>)#$1\n#g;
return $string;

}

###

sub escape_html {

my $text     = shift;
my $links    = shift;
my $nobreaks = shift;

$text =~ s/&/&amp;/g;
$text =~ s/"/&quot;/g;
$text =~ s/</&lt;/g;
$text =~ s/>/&gt;/g;
$text =~ y/\r//d;

if ($links) {
# URL stitching regexp. Too many false matches
#  $text =~ s#((?:http|https|ftp)://.*?)( |\t|\n\n|$)#(my $u = $1) =~ y~\n~~d; "<a href='$u' target='_blank'>$1</a>$2"#gise;
  $text =~ s#((?:http|https|ftp)://[^\s]+)#<a href="$1" target="_blank">$1</a>#gi
}

unless ($nobreaks) {

  $text =~ s/^ /&nbsp;/gm;
  while ($text =~ s/  /&nbsp; /g) {;}

  $text =~ s/\n\n/<p>/g;
  $text =~ s/\n/<br>/g;
}

return $text;

}

###

sub write_log {

my ($request, $connect, $username, $statuscode, $length) = @_;

printf LOG qq~%s - %s [%s] "%s %s %s" %s %s "%s" "%s"\n~, 
	$connect->peerhost,
	$username || "-",
	log_date_format(scalar gmtime),
	$request->method,
	$request->uri,
	$request->protocol,
	$statuscode,
	$length,
	$request->referer || "",
	$request->user_agent,
;

return 1;

}

###

sub log_date_format {

my @date = split(/ +/, shift);

$date[2] = substr("0$date[2]", -2);

return join(" ",
  join("/", @date[2,1,4]),
  $date[3],
  "+0000",
);

}

###

sub shortParseDate {

my @months = qw(Jan Feb Mar Apr May June July Aug Sept Oct Nov Dec);
my @days   = qw(Sun Mon Tue Wed Thu Fri Sat);

my @time = localtime(shift);

return join(" ", $days[$time[6]], $time[3], $months[$time[4]], $time[5] + 1900, join(":", map { substr("00$_", -2) } @time[2, 1]) );

}

###

sub parse_input {

my $input = shift;
my %return;

foreach (split(/&/, $input)) {
  s/\+/ /g;
  ($name, $value) = split(/=/, $_, 2);
  $name  =~ s/%(..)/pack("c",hex($1))/ge;
  $value =~ s/%(..)/pack("c",hex($1))/ge;
  $return{$name} = $value;
}

return %return;

}

###

sub wrap_text {

### In:   String and Integer
### Out:  Array of lines wrapped to width Integer including line break
### Note: Converts \n+ into a blank line paragraph break

my $input  = shift;
my $max    = shift;
my @output = ();
my $output;

$input =~ y/\r//d;

while ($input) {
  $input =~ s/^[ \t]*([^\n]{0,$max})//os;
  $output = $1;

  $output =~ s/\s*$//;
  next if (length($output) < $max);

  $output =~ s/(\s*)(\S*)$//;
  if (length($output)) {
    $input = "$2$input";
  } else { # Full line of non-spaces. Remove one to allow \n and
           # replace it in the input string
    $output .= substr($2, 0, -1);
    $input   = substr($2, -1) . $input;
  }

} continue {
  push (@output, $output);
  $input =~ s/^\n\n+// && push (@output, "");
  $input =~ s/^\n//
}

return @output;

}

###

sub parse_colours {

my $input = shift;

#$input =~ s~#([nwrgybmc])([^#]*)~<span class="colour\u$1">$2</span>~gi;

return $input;

}

###

sub ordinal {

my $number = shift;

   if ($number % 100 == 11) { return "th" }
elsif ($number % 100 == 12) { return "th" }
elsif ($number % 100 == 13) { return "th" }
elsif ($number %  10 ==  1) { return "st" }
elsif ($number %  10 ==  2) { return "nd" }
elsif ($number %  10 ==  3) { return "rd" }
else                        { return "th" }

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
