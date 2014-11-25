package EDF::Client::ParseDate;

# Copyright (c) 1995-2000 Sullivan Beck.  All rights reserved.
# This program is free software; you can redistribute it and/or modify it
# under the same terms as Perl itself.

###########################################################################
###########################################################################

use vars qw(%Lang %Curr %Cnf %Zone);

###########################################################################
# CUSTOMIZATION
###########################################################################
#
# See the section of the POD documentation section CUSTOMIZING DATE::MANIP
# below for a complete description of each of these variables.

@DatePath=();

### Date::Manip variables set in the global or personal config file

# Local timezone
$Cnf{"TZ"}="GMT";

# Timezone to work in (""=local, "IGNORE", or a timezone)
$Cnf{"ConvTZ"}="";

# Date::Manip internal format (0=YYYYMMDDHH:MN:SS, 1=YYYYHHMMDDHHMNSS)
$Cnf{"Internal"}=0;

# First day of the week (1=monday, 7=sunday).  ISO 8601 says monday.
$Cnf{"FirstDay"}=1;

# Set this to non-zero to be produce completely backwards compatible deltas
$Cnf{"DeltaSigns"}=0;

# If this is 0, use the ISO 8601 standard that Jan 4 is in week 1.  If 1,
# make week 1 contain Jan 1.
$Cnf{"Jan1Week1"}=0;

# 2 digit years fall into the 100 year period given by [ CURR-N,
# CURR+(99-N) ] where N is 0-99.  Default behavior is 89, but other useful
# numbers might be 0 (forced to be this year or later) and 99 (forced to be
# this year or earlier).  It can also be set to "c" (current century) or
# "cNN" (i.e.  c18 forces the year to bet 1800-1899).  Also accepts the
# form cNNNN to give the 100 year period NNNN to NNNN+99.
$Cnf{"YYtoYYYY"}=89;

# Set this to 1 if you want a long-running script to always update the
# timezone.  This will slow Date::Manip down.  Read the POD documentation.
$Cnf{"UpdateCurrTZ"}=0;

# Use this to force the current date to be set to this:
$Cnf{"ForceDate"}="";

###########################################################################

require 5.000;
require Exporter;
@ISA = qw(Exporter);
@EXPORT = qw(ParseDate);
@EXPORT_OK = qw(
   Date_Init
   ParseDateString
   Date_Cmp
   DateCalc
   ParseDateDelta
   Delta_Format
   Date_GetPrev
   Date_GetNext
   Date_SetTime
   Date_SetDateField
   Date_DaysInMonth
   Date_DayOfWeek
   Date_SecsSince1970
   Date_SecsSince1970GMT
   Date_DaysSince1BC
   Date_DayOfYear
   Date_DaysInYear
   Date_WeekOfYear
   Date_LeapYear
   Date_DaySuffix
   Date_ConvTZ
   Date_TimeZone
   Date_NthDayOfYear
);
use strict;
use integer;
use Carp;

use vars qw($VERSION);
$VERSION="5.39";

########################################################################
########################################################################

$Curr{"InitLang"}      = 1;     # Whether a language is being init'ed
$Curr{"InitDone"}      = 0;     # Whether Init_Date has been called

########################################################################
########################################################################
# THESE ARE THE MAIN ROUTINES
########################################################################
########################################################################

# Get rid of a problem with old versions of perl
no strict "vars";
# This sorts from longest to shortest element
sub sortByLength {
  return (length $b <=> length $a);
}
use strict "vars";

sub Date_Init {

  $Curr{"InitDone"}=1;
  local($_)=();
  my($internal,$firstday)=();
  my($var,$val,$file,@tmp)=();

  confess "ERROR: Unknown FirstDay in Date::Manip.\n"
    if (! &IsInt($Cnf{"FirstDay"},1,7));

  my(%lang,
     $tmp,%tmp,$tmp2,@tmp2,
     $i,$j,@tmp3,
     $zonesrfc,@zones)=();

  if ($Curr{"InitLang"}) {
    $Curr{"InitLang"}=0;
    &Date_Init_English(\%lang);

    #  variables for months
    #   Month   = "(jan|january|feb|february ... )"
    #   MonL    = [ "Jan","Feb",... ]
    #   MonthL  = [ "January","February", ... ]
    #   MonthH  = { "january"=>1, "jan"=>1, ... }

    $Lang{"MonthH"}={};
    $Lang{"MonthL"}=[];
    $Lang{"MonL"}=[];
    &Date_InitLists([$lang{"month_name"},
                     $lang{"month_abb"}],
                    \$Lang{"Month"},"lc,sort,back",
                    [$Lang{"MonthL"},
                     $Lang{"MonL"}],
                    [$Lang{"MonthH"},1]);

    #  variables for day of week
    #   Week   = "(mon|monday|tue|tuesday ... )"
    #   WL     = [ "M","T",... ]
    #   WkL    = [ "Mon","Tue",... ]
    #   WeekL  = [ "Monday","Tudesday",... ]
    #   WeekH  = { "monday"=>1,"mon"=>1,"m"=>1,... }

    $Lang{"WeekH"}={};
    $Lang{"WeekL"}=[];
    $Lang{"WkL"}=[];
    $Lang{"WL"}=[];
    &Date_InitLists([$lang{"day_name"},
                     $lang{"day_abb"}],
                    \$Lang{"Week"},"lc,sort,back",
                    [$Lang{"WeekL"},
                     $Lang{"WkL"}],
                    [$Lang{"WeekH"},1]);
    &Date_InitLists([$lang{"day_char"}],
                    "","lc",
                    [$Lang{"WL"}],
                    [\%tmp,1]);
    %{ $Lang{"WeekH"} } =
      (%{ $Lang{"WeekH"} },%tmp);

    #  variables for last
    #   Last      = "(last)"
    #   LastL     = [ "last" ]
    #   Each      = "(each)"
    #   EachL     = [ "each" ]
    #  variables for day of month
    #   DoM       = "(1st|first ... 31st)"
    #   DoML      = [ "1st","2nd",... "31st" ]
    #   DoMH      = { "1st"=>1,"first"=>1, ... "31st"=>31 }
    #  variables for week of month
    #   WoM       = "(1st|first| ... 5th|last)"
    #   WoMH      = { "1st"=>1, ... "5th"=>5,"last"=>-1 }

    $Lang{"LastL"}=$lang{"last"};
    &Date_InitStrings($lang{"last"},
                      \$Lang{"Last"},"lc,sort");

    $Lang{"EachL"}=$lang{"each"};
    &Date_InitStrings($lang{"each"},
                      \$Lang{"Each"},"lc,sort");

    $Lang{"DoMH"}={};
    $Lang{"DoML"}=[];
    &Date_InitLists([$lang{"num_suff"},
                     $lang{"num_word"}],
                    \$Lang{"DoM"},"lc,sort,back,escape",
                    [$Lang{"DoML"},
                     \@tmp],
                    [$Lang{"DoMH"},1]);

    @tmp=();
    foreach $tmp (keys %{ $Lang{"DoMH"} }) {
      $tmp2=$Lang{"DoMH"}{$tmp};
      if ($tmp2<6) {
        $Lang{"WoMH"}{$tmp} = $tmp2;
        push(@tmp,$tmp);
      }
    }
    foreach $tmp (@{ $Lang{"LastL"} }) {
      $Lang{"WoMH"}{$tmp} = -1;
      push(@tmp,$tmp);
    }
    &Date_InitStrings(\@tmp,\$Lang{"WoM"},
                      "lc,sort,back,escape");

    #  variables for AM or PM
    #   AM      = "(am)"
    #   PM      = "(pm)"
    #   AmPm    = "(am|pm)"
    #   AMstr   = "AM"
    #   PMstr   = "PM"

    &Date_InitStrings($lang{"am"},\$Lang{"AM"},"lc,sort,escape");
    &Date_InitStrings($lang{"pm"},\$Lang{"PM"},"lc,sort,escape");
    &Date_InitStrings([ @{$lang{"am"}},@{$lang{"pm"}} ],\$Lang{"AmPm"},
                      "lc,back,sort,escape");
    $Lang{"AMstr"}=$lang{"am"}[0];
    $Lang{"PMstr"}=$lang{"pm"}[0];

    #  variables for expressions used in parsing deltas
    #    Yabb   = "(?:y|yr|year|years)"
    #    Mabb   = similar for months
    #    Wabb   = similar for weeks
    #    Dabb   = similar for days
    #    Habb   = similar for hours
    #    MNabb  = similar for minutes
    #    Sabb   = similar for seconds
    #    Repl   = { "abb"=>"replacement" }
    # Whenever an abbreviation could potentially refer to two different
    # strings (M standing for Minutes or Months), the abbreviation must
    # be listed in Repl instead of in the appropriate Xabb values.  This
    # only applies to abbreviations which are substrings of other values
    # (so there is no confusion between Mn and Month).

    &Date_InitStrings($lang{"years"}  ,\$Lang{"Yabb"}, "lc,sort");
    &Date_InitStrings($lang{"months"} ,\$Lang{"Mabb"}, "lc,sort");
    &Date_InitStrings($lang{"weeks"}  ,\$Lang{"Wabb"}, "lc,sort");
    &Date_InitStrings($lang{"days"}   ,\$Lang{"Dabb"}, "lc,sort");
    &Date_InitStrings($lang{"hours"}  ,\$Lang{"Habb"}, "lc,sort");
    &Date_InitStrings($lang{"minutes"},\$Lang{"MNabb"},"lc,sort");
    &Date_InitStrings($lang{"seconds"},\$Lang{"Sabb"}, "lc,sort");
    $Lang{"Repl"}={};
    &Date_InitHash($lang{"replace"},undef,"lc",$Lang{"Repl"});

    #  variables for special dates that are offsets from now
    #    Now      = "(now|today)"
    #    Offset   = "(yesterday|tomorrow)"
    #    OffsetH  = { "yesterday"=>"-0:0:0:1:0:0:0",... ]
    #    Times    = "(noon|midnight)"
    #    TimesH   = { "noon"=>"12:00:00","midnight"=>"00:00:00" }
    #    SepHM    = hour/minute separator
    #    SepMS    = minute/second separator
    #    SepSS    = second/fraction separator

    $Lang{"TimesH"}={};
    &Date_InitHash($lang{"times"},
                   \$Lang{"Times"},"lc,sort,back",
                   $Lang{"TimesH"});
    &Date_InitStrings($lang{"now"},\$Lang{"Now"},"lc,sort");
    $Lang{"OffsetH"}={};
    &Date_InitHash($lang{"offset"},
                   \$Lang{"Offset"},"lc,sort,back",
                   $Lang{"OffsetH"});
    $Lang{"SepHM"}=$lang{"sephm"};
    $Lang{"SepMS"}=$lang{"sepms"};
    $Lang{"SepSS"}=$lang{"sepss"};

    #  variables for time zones
    #    zones      = regular expression with all zone names (EST)
    #    n2o        = a hash of all parsable zone names with their offsets
    #    tzones     = reguar expression with all tzdata timezones (US/Eastern)
    #    tz2z       = hash of all tzdata timezones to full timezone (EST#EDT)

    $zonesrfc=
      "idlw   -1200 ".  # International Date Line West
      "nt     -1100 ".  # Nome
      "hst    -1000 ".  # Hawaii Standard
      "cat    -1000 ".  # Central Alaska
      "ahst   -1000 ".  # Alaska-Hawaii Standard
      "akst   -0900 ".  # Alaska Standard
      "yst    -0900 ".  # Yukon Standard
      "hdt    -0900 ".  # Hawaii Daylight
      "akdt   -0800 ".  # Alaska Daylight
      "ydt    -0800 ".  # Yukon Daylight
      "pst    -0800 ".  # Pacific Standard
      "pdt    -0700 ".  # Pacific Daylight
      "mst    -0700 ".  # Mountain Standard
      "mdt    -0600 ".  # Mountain Daylight
      "cst    -0600 ".  # Central Standard
      "cdt    -0500 ".  # Central Daylight
      "est    -0500 ".  # Eastern Standard
      "sat    -0400 ".  # Chile
      "edt    -0400 ".  # Eastern Daylight
      "ast    -0400 ".  # Atlantic Standard
      #"nst   -0330 ".  # Newfoundland Standard      nst=North Sumatra    +0630
      "nft    -0330 ".  # Newfoundland
      #"gst   -0300 ".  # Greenland Standard         gst=Guam Standard    +1000
      #"bst   -0300 ".  # Brazil Standard            bst=British Summer   +0100
      "adt    -0300 ".  # Atlantic Daylight
      "ndt    -0230 ".  # Newfoundland Daylight
      "at     -0200 ".  # Azores
      "sast   -0200 ".  # South African Standard
      "wat    -0100 ".  # West Africa
      "gmt    +0000 ".  # Greenwich Mean
      "ut     +0000 ".  # Universal
      "utc    +0000 ".  # Universal (Coordinated)
      "wet    +0000 ".  # Western European
      "west   +0000 ".  # Alias for Western European
      "cet    +0100 ".  # Central European
      "fwt    +0100 ".  # French Winter
      "met    +0100 ".  # Middle European
      "mez    +0100 ".  # Middle European
      "mewt   +0100 ".  # Middle European Winter
      "swt    +0100 ".  # Swedish Winter
      "bst    +0100 ".  # British Summer             bst=Brazil standard  -0300
      "gb     +0100 ".  # GMT with daylight savings
      "eet    +0200 ".  # Eastern Europe, USSR Zone 1
      "cest   +0200 ".  # Central European Summer
      "fst    +0200 ".  # French Summer
      "ist    +0200 ".  # Israel standard
      "mest   +0200 ".  # Middle European Summer
      "mesz   +0200 ".  # Middle European Summer
      "metdst +0200 ".  # An alias for mest used by HP-UX
      "sst    +0200 ".  # Swedish Summer             sst=South Sumatra    +0700
      "bt     +0300 ".  # Baghdad, USSR Zone 2
      "eest   +0300 ".  # Eastern Europe Summer
      "eetedt +0300 ".  # Eastern Europe, USSR Zone 1
      "idt    +0300 ".  # Israel Daylight
      "msk    +0300 ".  # Moscow
      "it     +0330 ".  # Iran
      "zp4    +0400 ".  # USSR Zone 3
      "msd    +0400 ".  # Moscow Daylight
      "zp5    +0500 ".  # USSR Zone 4
      "ist    +0530 ".  # Indian Standard
      "zp6    +0600 ".  # USSR Zone 5
      "nst    +0630 ".  # North Sumatra              nst=Newfoundland Std -0330
      #"sst   +0700 ".  # South Sumatra, USSR Zone 6 sst=Swedish Summer   +0200
      "hkt    +0800 ".  # Hong Kong
      "sgt    +0800 ".  # Singapore
      "cct    +0800 ".  # China Coast, USSR Zone 7
      "awst   +0800 ".  # West Australian Standard
      "wst    +0800 ".  # West Australian Standard
      "pht    +0800 ".  # Asia Manila
      "kst    +0900 ".  # Republic of Korea
      "jst    +0900 ".  # Japan Standard, USSR Zone 8
      "rok    +0900 ".  # Republic of Korea
      "cast   +0930 ".  # Central Australian Standard
      "east   +1000 ".  # Eastern Australian Standard
      "gst    +1000 ".  # Guam Standard, USSR Zone 9 gst=Greenland Std    -0300
      "cadt   +1030 ".  # Central Australian Daylight
      "eadt   +1100 ".  # Eastern Australian Daylight
      "idle   +1200 ".  # International Date Line East
      "nzst   +1200 ".  # New Zealand Standard
      "nzt    +1200 ".  # New Zealand
      "nzdt   +1300 ".  # New Zealand Daylight
      "z +0000 ".
      "a +0100 b +0200 c +0300 d +0400 e +0500 f +0600 g +0700 h +0800 ".
      "i +0900 k +1000 l +1100 m +1200 ".
      "n -0100 o -0200 p -0300 q -0400 r -0500 s -0600 t -0700 u -0800 ".
      "v -0900 w -1000 x -1100 y -1200";

    $Zone{"n2o"} = {};
    ($Zone{"zones"},%{ $Zone{"n2o"} })=
      &Date_Regexp($zonesrfc,"sort,lc,under,back",
                   "keys");

    $tmp=
      "US/Pacific  PST8PDT ".
      "US/Mountain MST7MDT ".
      "US/Central  CST6CDT ".
      "US/Eastern  EST5EDT ".
      "Canada/Pacific  PST8PDT ".
      "Canada/Mountain MST7MDT ".
      "Canada/Central  CST6CDT ".
      "Canada/Eastern  EST5EDT";

    $Zone{"tz2z"} = {};
    ($Zone{"tzones"},%{ $Zone{"tz2z"} })=
      &Date_Regexp($tmp,"lc,under,back","keys");
    $Cnf{"TZ"}=&Date_TimeZone;

    #  misc. variables
    #    At     = "(?:at)"
    #    Of     = "(?:in|of)"
    #    On     = "(?:on)"
    #    Future = "(?:in)"
    #    Later  = "(?:later)"
    #    Past   = "(?:ago)"
    #    Next   = "(?:next)"
    #    Prev   = "(?:last|previous)"

    &Date_InitStrings($lang{"at"},    \$Lang{"At"},     "lc,sort");
    &Date_InitStrings($lang{"on"},    \$Lang{"On"},     "lc,sort");
    &Date_InitStrings($lang{"future"},\$Lang{"Future"}, "lc,sort");
    &Date_InitStrings($lang{"later"}, \$Lang{"Later"},  "lc,sort");
    &Date_InitStrings($lang{"past"},  \$Lang{"Past"},   "lc,sort");
    &Date_InitStrings($lang{"next"},  \$Lang{"Next"},   "lc,sort");
    &Date_InitStrings($lang{"prev"},  \$Lang{"Prev"},   "lc,sort");
    &Date_InitStrings($lang{"of"},    \$Lang{"Of"},     "lc,sort");

    ############### END OF LANGUAGE INITIALIZATION
  }

  # current time
  my($s,$mn,$h,$d,$m,$y,$wday,$yday,$isdst,$ampm,$wk)=();
  if ($Cnf{"ForceDate"}=~
      /^(\d{4})-(\d{2})-(\d{2})-(\d{2}):(\d{2}):(\d{2})$/) {
       ($y,$m,$d,$h,$mn,$s)=($1,$2,$3,$4,$5,$6);
  } else {
    ($s,$mn,$h,$d,$m,$y,$wday,$yday,$isdst)=localtime(time);
    $y+=1900;
    $m++;
  }
  &Date_DateCheck(\$y,\$m,\$d,\$h,\$mn,\$s,\$ampm,\$wk);
  $Curr{"Y"}=$y;
  $Curr{"M"}=$m;
  $Curr{"D"}=$d;
  $Curr{"H"}=$h;
  $Curr{"Mn"}=$mn;
  $Curr{"S"}=$s;
  $Curr{"AmPm"}=$ampm;
  $Curr{"Now"}=&Date_Join($y,$m,$d,$h,$mn,$s);

  # If we're in array context, let's return a list of config variables
  # that could be passed to Date_Init to get the same state as we're
  # currently in.
  if (wantarray) {
    # Some special variables that have to be in a specific order
    my(@special)=qw(IgnoreGlobalCnf GlobalCnf PersonalCnf PersonalCnfPath);
    my(%tmp)=map { $_,1 } @special;
    my(@tmp,$key,$val);
    foreach $key (@special) {
      $val=$Cnf{$key};
      push(@tmp,"$key=$val");
    }
    foreach $key (keys %Cnf) {
      next  if (exists $tmp{$key});
      $val=$Cnf{$key};
      push(@tmp,"$key=$val");
    }
    return @tmp;
  }
  return ();
}

sub ParseDateString {
  local($_)=@_;
  return ""  if (! $_);

  my($y,$m,$d,$h,$mn,$s,$i,$wofm,$dofw,$wk,$tmp,$z,$num,$iso,$ampm)=();
  my($date,$z2,$delta,$from,$falsefrom,$to,$which,$midnight)=();

  # We only need to reinitialize if we have to determine what NOW is.
  &Date_Init()  if (! $Curr{"InitDone"}  or  $Cnf{"UpdateCurrTZ"});

  # Unfortunately, some deltas can be parsed as dates.  An example is
  #    1 second  ==  1 2nd  ==  1 2
  # But, some dates can be parsed as deltas.  The most important being:
  #    1998010101:00:00
  # We'll check to see if a "date" can be parsed as a delta.  If so, we'll
  # assume that it is a delta (since they are much simpler, it is much
  # less likely that we'll mistake a delta for a date than vice versa)
  # unless it is an ISO-8601 date.
  #
  # This is important because we are using DateCalc to test whether a
  # string is a date or a delta.  Dates are tested first, so we need to
  # be able to pass a delta into this routine and have it correctly NOT
  # interpreted as a date.
  #
  # We will insist that the string contain something other than digits and
  # colons so that the following will get correctly interpreted as a date
  # rather than a delta:
  #     12:30
  #     19980101

  $delta="";
  $delta=&ParseDateDelta($_)  if (/[^:0-9]/);

  # Put parse in a simple loop for an easy exit.
 PARSE: {
    my(@tmp)=&Date_Split($_);
    if (@tmp) {
      ($y,$m,$d,$h,$mn,$s)=@tmp;
      last PARSE;
    }

    # Fundamental regular expressions

    my($month)=$Lang{"Month"};          # (jan|january|...)
    my(%month)=%{ $Lang{"MonthH"} };    # { jan=>1, ... }
    my($week)=$Lang{"Week"};            # (mon|monday|...)
    my(%week)=%{ $Lang{"WeekH"} };      # { mon=>1, monday=>1, ... }
    my($wom)=$Lang{"WoM"};              # (1st|...|fifth|last)
    my(%wom)=%{ $Lang{"WoMH"} };        # { 1st=>1,... fifth=>5,last=>-1 }
    my($dom)=$Lang{"DoM"};              # (1st|first|...31st)
    my(%dom)=%{ $Lang{"DoMH"} };        # { 1st=>1, first=>1, ... }
    my($ampmexp)=$Lang{"AmPm"};         # (am|pm)
    my($timeexp)=$Lang{"Times"};        # (noon|midnight)
    my($now)=$Lang{"Now"};              # (now|today)
    my($offset)=$Lang{"Offset"};        # (yesterday|tomorrow)
    my($zone)=$Zone{"zones"} . '(?:\s+|$)'; # (edt|est|...)\s+
    my($day)='\s*'.$Lang{"Dabb"};       # \s*(?:d|day|days)
    my($mabb)='\s*'.$Lang{"Mabb"};      # \s*(?:mon|month|months)
    my($wkabb)='\s*'.$Lang{"Wabb"};     # \s*(?:w|wk|week|weeks)
    my($next)='\s*'.$Lang{"Next"};      # \s*(?:next)
    my($prev)='\s*'.$Lang{"Prev"};      # \s*(?:last|previous)
    my($past)='\s*'.$Lang{"Past"};      # \s*(?:ago)
    my($future)='\s*'.$Lang{"Future"};  # \s*(?:in)
    my($later)='\s*'.$Lang{"Later"};    # \s*(?:later)
    my($at)=$Lang{"At"};                # (?:at)
    my($of)='\s*'.$Lang{"Of"};          # \s*(?:in|of)
    my($on)='(?:\s*'.$Lang{"On"}.'\s*|\s+)';
                                            # \s*(?:on)\s*    or  \s+
    my($last)='\s*'.$Lang{"Last"};      # \s*(?:last)
    my($hm)=$Lang{"SepHM"};             # :
    my($ms)=$Lang{"SepMS"};             # :
    my($ss)=$Lang{"SepSS"};             # .

    # Other regular expressions

    my($D4)='(\d{4})';            # 4 digits      (yr)
    my($YY)='(\d{4}|\d{2})';      # 2 or 4 digits (yr)
    my($DD)='(\d{2})';            # 2 digits      (mon/day/hr/min/sec)
    my($D) ='(\d{1,2})';          # 1 or 2 digit  (mon/day/hr)
    my($FS)="(?:$ss\\d+)?";       # fractional secs
    my($sep)='[\/.-]';            # non-ISO8601 m/d/yy separators
    # absolute time zone     +0700 (GMT)
    my($hzone)='(?:[0-1][0-9]|2[0-3])';                    # 00 - 23
    my($mzone)='(?:[0-5][0-9])';                           # 00 - 59
    my($zone2)='(?:\s*([+-](?:'."$hzone$mzone|$hzone:$mzone|$hzone))".
                                                           # +0700 +07:00 -07
      '(?:\s*\([^)]+\))?)';                                # (GMT)

    # A regular expression for the time EXCEPT for the hour part
    my($mnsec)="$hm$DD(?:$ms$DD$FS)?(?:\\s*$ampmexp)?";

    # A special regular expression for /YYYY:HH:MN:SS used by Apache
    my($apachetime)='(/\d{4}):' . "$DD$hm$DD$ms$DD";

    my($time)="";
    $ampm="";
    $date="";

    # Substitute all special time expressions.
    if (/(^|[^a-z])$timeexp($|[^a-z])/i) {
      $tmp=$2;
      $tmp=$Lang{"TimesH"}{$tmp};
      s/(^|[^a-z])$timeexp($|[^a-z])/$1 $tmp $3/i;
    }

    # Remove some punctuation
    s/[,]/ /g;

    # Make sure that ...7EST works (i.e. a timezone immediately following
    # a digit.
    s/(\d)$zone(\s+|$|[0-9])/$1 $2$3/i;
    $zone = '\s+'.$zone;

    # Remove the time
    $iso=1;
    $midnight=0;
    $from="24${hm}00(?:${ms}00)?";
    $falsefrom="${hm}24${ms}00";   # Don't trap XX:24:00
    $to="00${hm}00${ms}00";
    $midnight=1  if (!/$falsefrom/  &&  s/$from/$to/);

    if (/$D$mnsec/i || /$ampmexp/i) {
      $iso=0;
      $tmp=0;
      $tmp=1  if (/$mnsec$zone2?\s*$/i);  # or /$mnsec$zone/ ??
      $tmp=0  if (/$ampmexp/i);
      if (s/$apachetime$zone()/$1 /i  ||
          s/$apachetime$zone2?/$1 /i  ||
          s/(^|[^a-z])$at\s*$D$mnsec$zone()/$1 /i  ||
          s/(^|[^a-z])$at\s*$D$mnsec$zone2?/$1 /i  ||
          s/(^|[^0-9])(\d)$mnsec$zone()/$1 /i ||
          s/(^|[^0-9])(\d)$mnsec$zone2?/$1 /i ||
          (s/(t)$D$mnsec$zone()/$1 /i and (($iso=-$tmp) || 1))  ||
          (s/(t)$D$mnsec$zone2?/$1 /i and (($iso=-$tmp) || 1))  ||
          (s/()$DD$mnsec$zone()/ /i and (($iso=$tmp) || 1)) ||
          (s/()$DD$mnsec$zone2?/ /i and (($iso=$tmp) || 1))  ||
          s/(^|$at\s*|\s+)$D()()\s*$ampmexp$zone()/ /i  ||
          s/(^|$at\s*|\s+)$D()()\s*$ampmexp$zone2?/ /i  ||
          0
         ) {
        ($h,$mn,$s,$ampm,$z,$z2)=($2,$3,$4,$5,$6,$7);
        if (defined ($z)) {
          if ($z =~ /^[+-]\d{2}:\d{2}$/) {
            $z=~ s/://;
          } elsif ($z =~ /^[+-]\d{2}$/) {
            $z .= "00";
          }
        }
        $time=1;
        &Date_TimeCheck(\$h,\$mn,\$s,\$ampm);
        $y=$m=$d="";
        # We're going to be calling TimeCheck again below (when we check the
        # final date), so get rid of $ampm so that we don't have an error
        # due to "15:30:00 PM".  It'll get reset below.
        $ampm="";
        last PARSE  if (/^\s*$/);
      }
    }
    $time=0  if ($time ne "1");
    s/\s+$//;
    s/^\s+//;

    # dateTtime ISO 8601 formats
    my($orig)=$_;
    s/t$//i  if ($iso<0);
        
    # Parse ISO 8601 dates now (which may still have a zone stuck to it).
    if ( ($iso && /^[0-9-]+(W[0-9-]+)?$zone?$/i)  ||
         ($iso && /^[0-9-]+(W[0-9-]+)?$zone2?$/i)  ||
         0) {

      # ISO 8601 dates
      s,-, ,g;            # Change all ISO8601 seps to spaces
      s/^\s+//;
      s/\s+$//;

      if (/^$D4\s*$DD\s*$DD\s*$DD(?:$DD(?:$DD\d*)?)?$zone2?$/  ||
          /^$D4\s*$DD\s*$DD\s*$DD(?:$DD(?:$DD\d*)?)?$zone?()$/i  ||
          /^$DD\s+$DD\s*$DD\s*$DD(?:$DD(?:$DD\d*)?)?$zone2?$/  ||
          /^$DD\s+$DD\s*$DD\s*$DD(?:$DD(?:$DD\d*)?)?$zone?()$/i  ||
          0
         ) {
        # ISO 8601 Dates with times
        #    YYYYMMDDHHMNSSFFFF
        #    YYYYMMDDHHMNSS
        #    YYYYMMDDHHMN
        #    YYYYMMDDHH
        #    YY MMDDHHMNSSFFFF
        #    YY MMDDHHMNSS
        #    YY MMDDHHMN
        #    YY MMDDHH
        ($y,$m,$d,$h,$mn,$s,$tmp,$z2)=($1,$2,$3,$4,$5,$6,$7,$8);
        if ($h==24 && $mn==0 && $s==0) {
          $h=0;
          $midnight=1;
        }
        $z=""    if (! $h);
        return ""  if ($tmp  and  $z);
        $z=$tmp    if ($tmp  and  $tmp);
        return ""  if ($time);
        last PARSE;

      } elsif (/^$D4(?:\s*$DD(?:\s*$DD)?)?$/  ||
               /^$DD(?:\s+$DD(?:\s*$DD)?)?$/) {
        # ISO 8601 Dates
        #    YYYYMMDD
        #    YYYYMM
        #    YYYY
        #    YY MMDD
        #    YY MM
        #    YY
        ($y,$m,$d)=($1,$2,$3);
        last PARSE;

      } elsif (/^$YY\s+$D\s+$D/) {
        # YY-M-D
        ($y,$m,$d)=($1,$2,$3);
        last PARSE;

      } elsif (/^$YY\s*W$DD\s*(\d)?$/i) {
        # YY-W##-D
        ($y,$wofm,$dofw)=($1,$2,$3);
        ($y,$m,$d)=&Date_NthWeekOfYear($y,$wofm,$dofw);
        last PARSE;

      } elsif (/^$D4\s*(\d{3})$/ ||
               /^$DD\s*(\d{3})$/) {
        # YYDOY
        ($y,$which)=($1,$2);
        ($y,$m,$d)=&Date_NthDayOfYear($y,$which);
        last PARSE;

      } elsif ($iso<0) {
        # We confused something like 1999/August12:00:00
        # with a dateTtime format
        $_=$orig;

      } else {
        return "";
      }
    }

    # All deltas that are not ISO-8601 dates are NOT dates.
    return ""  if ($Curr{"InCalc"}  &&  $delta);
    if ($delta) {
      &Date_Init()  if (! $Cnf{"UpdateCurrTZ"});
      return &DateCalc_DateDelta($Curr{"Now"},$delta);
    }

    # Check for some special types of dates (next, prev)
    foreach $from (keys %{ $Lang{"Repl"} }) {
      $to=$Lang{"Repl"}{$from};
      s/(^|[^a-z])$from($|[^a-z])/$1$to$2/i;
    }
    if (/$wom/i  ||  /$future/i  ||  /$later/i  ||  /$past/i  ||
        /$next/i  ||  /$prev/i  ||  /^$week$/i  ||  /$wkabb/i) {
      $tmp=0;

      if (/^$wom\s*$week$of\s*$month\s*$YY?$/i) {
        # last friday in October 95
        ($wofm,$dofw,$m,$y)=($1,$2,$3,$4);
        # fix $m, $y
        return ""  if (&Date_DateCheck(\$y,\$m,\$d,\$h,\$mn,\$s,\$ampm,\$wk));
        $dofw=$week{lc($dofw)};
        $wofm=$wom{lc($wofm)};
        # Get the first day of the month
        $date=&Date_Join($y,$m,1,$h,$mn,$s);
        if ($wofm==-1) {
          $date=&DateCalc_DateDelta($date,"+0:1:0:0:0:0:0");
          $date=&Date_GetPrev($date,$dofw,0);
        } else {
          for ($i=0; $i<$wofm; $i++) {
            if ($i==0) {
              $date=&Date_GetNext($date,$dofw,1);
            } else {
              $date=&Date_GetNext($date,$dofw,0);
            }
          }
        }
        last PARSE;

      } elsif (/^$last$day$of\s*$month(?:$of?\s*$YY)?/i) {
        # last day in month
        ($m,$y)=($1,$2);
        &Date_Init()  if (! $Cnf{"UpdateCurrTZ"});
        $y=&Date_FixYear($y)  if (! defined $y  or  length($y)<4);
        $m=$month{lc($m)};
        $d=&Date_DaysInMonth($m,$y);
        last PARSE;

      } elsif (/^$week$/i) {
        # friday
        ($dofw)=($1);
        &Date_Init()  if (! $Cnf{"UpdateCurrTZ"});
        $date=&Date_GetPrev($Curr{"Now"},$Cnf{"FirstDay"},1);
        $date=&Date_GetNext($date,$dofw,1,$h,$mn,$s);
        last PARSE;

      } elsif (/^$next\s*$week$/i) {
        # next friday
        ($dofw)=($1);
        &Date_Init()  if (! $Cnf{"UpdateCurrTZ"});
        $date=&Date_GetNext($Curr{"Now"},$dofw,0,$h,$mn,$s);
        last PARSE;

      } elsif (/^$prev\s*$week$/i) {
        # last friday
        ($dofw)=($1);
        &Date_Init()  if (! $Cnf{"UpdateCurrTZ"});
        $date=&Date_GetPrev($Curr{"Now"},$dofw,0,$h,$mn,$s);
        last PARSE;

      } elsif (/^$next$wkabb$/i) {
        # next week
        &Date_Init()  if (! $Cnf{"UpdateCurrTZ"});
        $date=&DateCalc_DateDelta($Curr{"Now"},"+0:0:1:0:0:0:0");
        $date=&Date_SetTime($date,$h,$mn,$s)  if (defined $h);
        last PARSE;
      } elsif (/^$prev$wkabb$/i) {
        # last week
        &Date_Init()  if (! $Cnf{"UpdateCurrTZ"});
        $date=&DateCalc_DateDelta($Curr{"Now"},"-0:0:1:0:0:0:0");
        $date=&Date_SetTime($date,$h,$mn,$s)  if (defined $h);
        last PARSE;

      } elsif (/^$next$mabb$/i) {
        # next month
        &Date_Init()  if (! $Cnf{"UpdateCurrTZ"});
        $date=&DateCalc_DateDelta($Curr{"Now"},"+0:1:0:0:0:0:0");
        $date=&Date_SetTime($date,$h,$mn,$s)  if (defined $h);
        last PARSE;
      } elsif (/^$prev$mabb$/i) {
        # last month
        &Date_Init()  if (! $Cnf{"UpdateCurrTZ"});
        $date=&DateCalc_DateDelta($Curr{"Now"},"-0:1:0:0:0:0:0");
        $date=&Date_SetTime($date,$h,$mn,$s)  if (defined $h);
        last PARSE;

      } elsif (/^$future\s*(\d+)$day$/i  ||
               /^(\d+)$day$later$/i) {
        # in 2 days
        # 2 days later
        ($num)=($1);
        &Date_Init()  if (! $Cnf{"UpdateCurrTZ"});
        $date=&DateCalc_DateDelta($Curr{"Now"},"+0:0:0:$num:0:0:0");
        $date=&Date_SetTime($date,$h,$mn,$s)  if (defined $h);
        last PARSE;
      } elsif (/^(\d+)$day$past$/i) {
        # 2 days ago
        ($num)=($1);
        &Date_Init()  if (! $Cnf{"UpdateCurrTZ"});
        $date=&DateCalc_DateDelta($Curr{"Now"},"-0:0:0:$num:0:0:0");
        $date=&Date_SetTime($date,$h,$mn,$s)  if (defined $h);
        last PARSE;

      } elsif (/^$future\s*(\d+)$wkabb$/i  ||
               /^(\d+)$wkabb$later$/i) {
        # in 2 weeks
        # 2 weeks later
        ($num)=($1);
        &Date_Init()  if (! $Cnf{"UpdateCurrTZ"});
        $date=&DateCalc_DateDelta($Curr{"Now"},"+0:0:$num:0:0:0:0");
        $date=&Date_SetTime($date,$h,$mn,$s)  if (defined $h);
        last PARSE;
      } elsif (/^(\d+)$wkabb$past$/i) {
        # 2 weeks ago
        ($num)=($1);
        &Date_Init()  if (! $Cnf{"UpdateCurrTZ"});
        $date=&DateCalc_DateDelta($Curr{"Now"},"-0:0:$num:0:0:0:0");
        $date=&Date_SetTime($date,$h,$mn,$s)  if (defined $h);
        last PARSE;

      } elsif (/^$future\s*(\d+)$mabb$/i  ||
               /^(\d+)$mabb$later$/i) {
        # in 2 months
        # 2 months later
        ($num)=($1);
        &Date_Init()  if (! $Cnf{"UpdateCurrTZ"});
        $date=&DateCalc_DateDelta($Curr{"Now"},"+0:$num:0:0:0:0:0");
        $date=&Date_SetTime($date,$h,$mn,$s)  if (defined $h);
        last PARSE;
      } elsif (/^(\d+)$mabb$past$/i) {
        # 2 months ago
        ($num)=($1);
        &Date_Init()  if (! $Cnf{"UpdateCurrTZ"});
        $date=&DateCalc_DateDelta($Curr{"Now"},"-0:$num:0:0:0:0:0");
        $date=&Date_SetTime($date,$h,$mn,$s)  if (defined $h);
        last PARSE;

      } elsif (/^$week$future\s*(\d+)$wkabb$/i  ||
               /^$week\s*(\d+)$wkabb$later$/i) {
        # friday in 2 weeks
        # friday 2 weeks later
        ($dofw,$num)=($1,$2);
        $tmp="+";
      } elsif (/^$week\s*(\d+)$wkabb$past$/i) {
        # friday 2 weeks ago
        ($dofw,$num)=($1,$2);
        $tmp="-";
      } elsif (/^$future\s*(\d+)$wkabb$on$week$/i  ||
               /^(\d+)$wkabb$later$on$week$/i) {
        # in 2 weeks on friday
        # 2 weeks later on friday
        ($num,$dofw)=($1,$2);
        $tmp="+"
      } elsif (/^(\d+)$wkabb$past$on$week$/i) {
        # 2 weeks ago on friday
        ($num,$dofw)=($1,$2);
        $tmp="-";
      } elsif (/^$week\s*$wkabb$/i) {
        # monday week    (British date: in 1 week on monday)
        $dofw=$1;
        $num=1;
        $tmp="+";
      } elsif (/^$now\s*$wkabb$/i) {
        # today week     (British date: 1 week from today)
        &Date_Init()  if (! $Cnf{"UpdateCurrTZ"});
        $date=&DateCalc_DateDelta($Curr{"Now"},"+0:0:1:0:0:0:0");
        $date=&Date_SetTime($date,$h,$mn,$s)  if (defined $h);
        last PARSE;
      } elsif (/^$offset\s*$wkabb$/i) {
        # tomorrow week  (British date: 1 week from tomorrow)
        ($offset)=($1);
        &Date_Init()  if (! $Cnf{"UpdateCurrTZ"});
        $offset=$Lang{"OffsetH"}{lc($offset)};
        $date=&DateCalc_DateDelta($Curr{"Now"},$offset);
        $date=&DateCalc_DateDelta($date,"+0:0:1:0:0:0:0");
        if ($time) {
          return ""
            if (&Date_DateCheck(\$y,\$m,\$d,\$h,\$mn,\$s,\$ampm,\$wk));
          $date=&Date_SetTime($date,$h,$mn,$s);
        }
        last PARSE;
      }

      if ($tmp) {
        &Date_Init()  if (! $Cnf{"UpdateCurrTZ"});
        $date=&DateCalc_DateDelta($Curr{"Now"},
                                  $tmp . "0:0:$num:0:0:0:0");
        $date=&Date_GetPrev($date,$Cnf{"FirstDay"},1);
        $date=&Date_GetNext($date,$dofw,1,$h,$mn,$s);
        last PARSE;
      }
    }

    # Change (2nd, second) to 2
    $tmp=0;
    if (/(^|[^a-z0-9])$dom($|[^a-z0-9])/i) {
      if (/^\s*$dom\s*$/) {
        ($d)=($1);
        $d=$dom{lc($d)};
        $m=$Curr{"M"};
        last PARSE;
      }
      $tmp=lc($2);
      $tmp=$dom{"$tmp"};
      s/(^|[^a-z])$dom($|[^a-z])/$1 $tmp $3/i;
      s/^\s+//;
      s/\s+$//;
    }

    # Another set of special dates (Nth week)
    if (/^$D\s*$week(?:$of?\s*$YY)?$/i) {
      # 22nd sunday in 1996
      ($which,$dofw,$y)=($1,$2,$3);
      $y=$Curr{"Y"}  if (! $y);
      $tmp=&Date_GetNext("$y-01-01",$dofw,0);
      if ($which>1) {
        $tmp=&DateCalc_DateDelta($tmp,"+0:0:".($which-1).":0:0:0:0");
      }
      ($y,$m,$d)=(&Date_Split($tmp))[0..2];
      last PARSE;
    } elsif (/^$week$wkabb\s*$D(?:$of?\s*$YY)?$/i  ||
             /^$week\s*$D$wkabb(?:$of?\s*$YY)?$/i) {
      # sunday week 22 in 1996
      # sunday 22nd week in 1996
      ($dofw,$which,$y)=($1,$2,$3);
      ($y,$m,$d)=&Date_NthWeekOfYear($y,$which,$dofw);
      last PARSE;
    }

    # Get rid of day of week
    if (/(^|[^a-z])$week($|[^a-z])/i) {
      $wk=$2;
      (s/(^|[^a-z])$week,/$1 /i) ||
        s/(^|[^a-z])$week($|[^a-z])/$1 $3/i;
      s/^\s+//;
      s/\s+$//;
    }

    {
      # Non-ISO8601 dates
      s,\s*$sep\s*, ,g;     # change all non-ISO8601 seps to spaces
      s,^\s*,,;             # remove leading/trailing space
      s,\s*$,,;

      if (/^$D\s+$D(?:\s+$YY)?$/) {
        # DD MM YY
        ($d,$m,$y)=($1,$2,$3);
        last PARSE;

      } elsif (/^$D4\s*$D\s*$D$/) {
        # YYYY MM DD
        ($y,$m,$d)=($1,$2,$3);
        last PARSE;

      } elsif (s/(^|[^a-z])$month($|[^a-z])/$1 $3/i) {
        ($m)=($2);

        if (/^\s*$D(?:\s+$YY)?\s*$/) {
          # mmm DD YY
          # DD mmm YY
          # DD YY mmm
          ($d,$y)=($1,$2);
          last PARSE;

        } elsif (/^\s*$D$D4\s*$/) {
          # mmm DD YYYY
          # DD mmm YYYY
          # DD YYYY mmm
          ($d,$y)=($1,$2);
          last PARSE;

        } elsif (/^\s*$D4\s*$D\s*$/) {
          # mmm YYYY DD
          # YYYY mmm DD
          # YYYY DD mmm
          ($y,$d)=($1,$2);
          last PARSE;

        } elsif (/^\s*$D4\s*$/) {
          # mmm YYYY
          # YYYY mmm
          ($y,$d)=($1,1);
          last PARSE;

        } else {
          return "";
        }

      } elsif (/^epoch\s*(\d+)$/i) {
        $s=$1;
        $date=&DateCalc("1970-01-01 00:00 GMT","+0:0:$s");

      } elsif (/^$now$/i) {
        # now, today
        &Date_Init()  if (! $Cnf{"UpdateCurrTZ"});
        $date=$Curr{"Now"};
        if ($time) {
          return ""
            if (&Date_DateCheck(\$y,\$m,\$d,\$h,\$mn,\$s,\$ampm,\$wk));
          $date=&Date_SetTime($date,$h,$mn,$s);
        }
        last PARSE;

      } elsif (/^$offset$/i) {
        # yesterday, tomorrow
        ($offset)=($1);
        &Date_Init()  if (! $Cnf{"UpdateCurrTZ"});
        $offset=$Lang{"OffsetH"}{lc($offset)};
        $date=&DateCalc_DateDelta($Curr{"Now"},$offset);
        if ($time) {
          return ""
            if (&Date_DateCheck(\$y,\$m,\$d,\$h,\$mn,\$s,\$ampm,\$wk));
          $date=&Date_SetTime($date,$h,$mn,$s);
        }
        last PARSE;

      } else {
        return "";
      }
    }
  }

  if (! $date) {
    return ""  if (&Date_DateCheck(\$y,\$m,\$d,\$h,\$mn,\$s,\$ampm,\$wk));
    $date=&Date_Join($y,$m,$d,$h,$mn,$s);
  }
  $date=&Date_ConvTZ($date,$z);
  if ($midnight) {
    $date=&DateCalc_DateDelta($date,"+0:0:0:1:0:0:0");
  }
  return $date;
}

sub ParseDate {
  &Date_Init()  if (! $Curr{"InitDone"});
  my($args,@args,@a,$ref,$date)=();
  @a=@_;

  # @a : is the list of args to ParseDate.  Currently, only one argument
  #      is allowed and it must be a scalar (or a reference to a scalar)
  #      or a reference to an array.

  if ($#a!=0) {
    print "ERROR:  Invalid number of arguments to ParseDate.\n";
    return "";
  }
  $args=$a[0];
  $ref=ref $args;
  if (! $ref) {
    return $args  if (&Date_Split($args));
    @args=($args);
  } elsif ($ref eq "ARRAY") {
    @args=@$args;
  } elsif ($ref eq "SCALAR") {
    return $$args  if (&Date_Split($$args));
    @args=($$args);
  } else {
    print "ERROR:  Invalid arguments to ParseDate.\n";
    return "";
  }
  @a=@args;

  # @args : a list containing all the arguments (dereferenced if appropriate)
  # @a    : a list containing all the arguments currently being examined
  # $ref  : nil, "SCALAR", or "ARRAY" depending on whether a scalar, a
  #         reference to a scalar, or a reference to an array was passed in
  # $args : the scalar or refererence passed in

 PARSE: while($#a>=0) {
    $date=join(" ",@a);
    $date=&ParseDateString($date);
    last  if ($date);
    pop(@a);
  } # PARSE

  splice(@args,0,$#a + 1);
  @$args=@args  if (defined $ref  and  $ref eq "ARRAY");

  return Date_SecsSince1970(Date_Split($date));
#  $date;
}

sub Date_Cmp {
  my($D1,$D2)=@_;
  my($date1)=&ParseDateString($D1);
  my($date2)=&ParseDateString($D2);
  return $date1 cmp $date2;
}

# **NOTE**
# The calc routines all call parse routines, so it is never necessary to
# call Date_Init in the calc routines.
sub DateCalc {
  my($D1,$D2)=@_;

  my(@date,@delta,$ret,$tmp,$old)=();

  $old=$Curr{"InCalc"};
  $Curr{"InCalc"}=1;
  if ($tmp=&ParseDateString($D1)) {
    # If we've already parsed the date, we don't want to do it a second
    # time (so we don't convert timezones twice).
    if (&Date_Split($D1)) {
      push(@date,$D1);
    } else {
      push(@date,$tmp);
    }
  } elsif ($tmp=&ParseDateDelta($D1)) {
    push(@delta,$tmp);
  } else {
    return;
  }

  if ($tmp=&ParseDateString($D2)) {
    if (&Date_Split($D2)) {
      push(@date,$D2);
    } else {
      push(@date,$tmp);
    }
  } elsif ($tmp=&ParseDateDelta($D2)) {
    push(@delta,$tmp);
  } else {
    return;
  }
  $Curr{"InCalc"}=$old;

  if ($#date==1) {
    $ret=&DateCalc_DateDate(@date);
  } elsif ($#date==0) {
    $ret=&DateCalc_DateDelta(@date,@delta);
  } else {
    $ret=&DateCalc_DeltaDelta(@delta);
  }
  $ret;
}

sub ParseDateDelta {
  my($args,@args,@a,$ref)=();
  local($_)=();
  @a=@_;

  # @a : is the list of args to ParseDateDelta.  Currently, only one argument
  #      is allowed and it must be a scalar (or a reference to a scalar)
  #      or a reference to an array.

  if ($#a!=0) {
    print "ERROR:  Invalid number of arguments to ParseDateDelta.\n";
    return "";
  }
  $args=$a[0];
  $ref=ref $args;
  if (! $ref) {
    @args=($args);
  } elsif ($ref eq "ARRAY") {
    @args=@$args;
  } elsif ($ref eq "SCALAR") {
    @args=($$args);
  } else {
    print "ERROR:  Invalid arguments to ParseDateDelta.\n";
    return "";
  }
  @a=@args;

  # @args : a list containing all the arguments (dereferenced if appropriate)
  # @a    : a list containing all the arguments currently being examined
  # $ref  : nil, "SCALAR", or "ARRAY" depending on whether a scalar, a
  #         reference to a scalar, or a reference to an array was passed in
  # $args : the scalar or refererence passed in

  my(@colon,@delta,$delta,$dir,$colon,$sign,$val)=();
  my($len,$tmp,$tmp2,$tmpl)=();
  my($from,$to)=();

  &Date_Init()  if (! $Curr{"InitDone"});
  my($signexp)='([+-]?)';
  my($numexp)='(\d+)';
  my($exp1)="(?: \\s* $signexp \\s* $numexp \\s*)";
  my($yexp,$mexp,$wexp,$dexp,$hexp,$mnexp,$sexp,$i)=();
  $yexp=$mexp=$wexp=$dexp=$hexp=$mnexp=$sexp="()()";
  $yexp ="(?: $exp1 ". $Lang{"Yabb"} .")?";
  $mexp ="(?: $exp1 ". $Lang{"Mabb"} .")?";
  $wexp ="(?: $exp1 ". $Lang{"Wabb"} .")?";
  $dexp ="(?: $exp1 ". $Lang{"Dabb"} .")?";
  $hexp ="(?: $exp1 ". $Lang{"Habb"} .")?";
  $mnexp="(?: $exp1 ". $Lang{"MNabb"}.")?";
  $sexp ="(?: $exp1 ". $Lang{"Sabb"} ."?)?";
  my($future)=$Lang{"Future"};
  my($later)=$Lang{"Later"};
  my($past)=$Lang{"Past"};

  $delta="";
 PARSE: while (@a) {
    $_ = join(" ", grep {defined;} @a);
    s/\s+$//;

    foreach $from (keys %{ $Lang{"Repl"} }) {
      $to=$Lang{"Repl"}{$from};
      s/(^|[^a-z])$from($|[^a-z])/$1$to$2/i;
    }

    # in or ago
    #
    # We need to make sure that $later, $future, and $past don't contain each
    # other... Romanian pointed this out where $past is "in urma" and $future
    # is "in".  When they do, we have to take this into account.
    #   $len  length of best match (greatest wins)
    #   $tmp  string after best match
    #   $dir  direction (prior, after) of best match
    #
    #   $tmp2 string before/after current match
    #   $tmpl length of current match

    $len=0;
    $tmp=$_;
    $dir=1;

    $tmp2=$_;
    if ($tmp2 =~ s/(^|[^a-z])($future)($|[^a-z])/$1 $3/i) {
      $tmpl=length($2);
      if ($tmpl>$len) {
        $tmp=$tmp2;
        $dir=1;
        $len=$tmpl;
      }
    }

    $tmp2=$_;
    if ($tmp2 =~ s/(^|[^a-z])($later)($|[^a-z])/$1 $3/i) {
      $tmpl=length($2);
      if ($tmpl>$len) {
        $tmp=$tmp2;
        $dir=1;
        $len=$tmpl;
      }
    }

    $tmp2=$_;
    if ($tmp2 =~ s/(^|[^a-z])($past)($|[^a-z])/$1 $3/i) {
      $tmpl=length($2);
      if ($tmpl>$len) {
        $tmp=$tmp2;
        $dir=-1;
        $len=$tmpl;
      }
    }

    $_ = $tmp;
    s/\s*$//;

    # the colon part of the delta
    $colon="";
    if (s/($signexp?$numexp?(:($signexp?$numexp)?){1,6})$//) {
      $colon=$1;
      s/\s+$//;
    }
    @colon=split(/:/,$colon);

    # the non-colon part of the delta
    $sign="+";
    @delta=();
    $i=6;
    foreach $exp1 ($yexp,$mexp,$wexp,$dexp,$hexp,$mnexp,$sexp) {
      last  if ($#colon>=$i--);
      $val=0;
      if (s/^$exp1//ix) {
        $val=$2   if ($2);
        $sign=$1  if ($1);
      }
      push(@delta,"$sign$val");
    }
    if (! /^\s*$/) {
      pop(@a);
      next PARSE;
    }

    # make sure that the colon part has a sign
    for ($i=0; $i<=$#colon; $i++) {
      $val=0;
      if ($colon[$i] =~ /^$signexp$numexp?/) {
        $val=$2   if ($2);
        $sign=$1  if ($1);
      }
      $colon[$i] = "$sign$val";
    }

    # combine the two
    push(@delta,@colon);
    if ($dir<0) {
      for ($i=0; $i<=$#delta; $i++) {
        $delta[$i] =~ tr/-+/+-/;
      }
    }

    # form the delta and shift off the valid part
    $delta=join(":",@delta);
    splice(@args,0,$#a+1);
    @$args=@args  if (defined $ref  and  $ref eq "ARRAY");
    last PARSE;
  }

  $delta=&Delta_Normalize($delta);
  return $delta;
}

# Can't be in "use integer" because we're doing decimal arithmatic
no integer;
sub Delta_Format {
  my($delta,$dec,@format)=@_;
  $delta=&ParseDateDelta($delta);
  return ""  if (! $delta);
  my(@out,%f,$out,$c1,$c2,$scalar,$format)=();
  local($_)=$delta;
  my($y,$M,$w,$d,$h,$m,$s)=&Delta_Split($delta);
  # Get rid of positive signs.
  ($y,$M,$w,$d,$h,$m,$s)=map { 1*$_; }($y,$M,$w,$d,$h,$m,$s);

  if (defined $dec  &&  $dec>0) {
    $dec="%." . ($dec*1) . "f";
  } else {
    $dec="%f";
  }

  if (! wantarray) {
    $format=join(" ",@format);
    @format=($format);
    $scalar=1;
  }

  # Length of each unit in seconds
  my($sl,$ml,$hl,$dl,$wl)=();
  $sl = 1;
  $ml = $sl*60;
  $hl = $ml*60;
  $dl = $hl*24;
  $wl = $dl*7;

  # The decimal amount of each unit contained in all smaller units
  my($yd,$Md,$sd,$md,$hd,$dd,$wd)=();
  $yd = $M/12;
  $Md = 0;

  $wd = ($d*$dl + $h*$hl + $m*$ml + $s*$sl)/$wl;
  $dd =          ($h*$hl + $m*$ml + $s*$sl)/$dl;
  $hd =                   ($m*$ml + $s*$sl)/$hl;
  $md =                            ($s*$sl)/$ml;
  $sd = 0;

  # The amount of each unit contained in higher units.
  my($yh,$Mh,$sh,$mh,$hh,$dh,$wh)=();
  $yh = 0;
  $Mh = ($yh+$y)*12;

  $wh = 0;
  $dh = ($wh+$w)*7;
  $hh = ($dh+$d)*24;
  $mh = ($hh+$h)*60;
  $sh = ($mh+$m)*60;

  # Set up the formats

  $f{"yv"} = $y;
  $f{"Mv"} = $M;
  $f{"wv"} = $w;
  $f{"dv"} = $d;
  $f{"hv"} = $h;
  $f{"mv"} = $m;
  $f{"sv"} = $s;

  $f{"yh"} = $y+$yh;
  $f{"Mh"} = $M+$Mh;
  $f{"wh"} = $w+$wh;
  $f{"dh"} = $d+$dh;
  $f{"hh"} = $h+$hh;
  $f{"mh"} = $m+$mh;
  $f{"sh"} = $s+$sh;

  $f{"yd"} = sprintf($dec,$y+$yd);
  $f{"Md"} = sprintf($dec,$M+$Md);
  $f{"wd"} = sprintf($dec,$w+$wd);
  $f{"dd"} = sprintf($dec,$d+$dd);
  $f{"hd"} = sprintf($dec,$h+$hd);
  $f{"md"} = sprintf($dec,$m+$md);
  $f{"sd"} = sprintf($dec,$s+$sd);

  $f{"yt"} = sprintf($dec,$yh+$y+$yd);
  $f{"Mt"} = sprintf($dec,$Mh+$M+$Md);
  $f{"wt"} = sprintf($dec,$wh+$w+$wd);
  $f{"dt"} = sprintf($dec,$dh+$d+$dd);
  $f{"ht"} = sprintf($dec,$hh+$h+$hd);
  $f{"mt"} = sprintf($dec,$mh+$m+$md);
  $f{"st"} = sprintf($dec,$sh+$s+$sd);

  $f{"%"}  = "%";

  foreach $format (@format) {
    $format=reverse($format);
    $out="";
  PARSE: while ($format) {
      $c1=chop($format);
      if ($c1 eq "%") {
        $c1=chop($format);
        if (exists($f{$c1})) {
          $out .= $f{$c1};
          next PARSE;
        }
        $c2=chop($format);
        if (exists($f{"$c1$c2"})) {
          $out .= $f{"$c1$c2"};
          next PARSE;
        }
        $out .= $c1;
        $format .= $c2;
      } else {
        $out .= $c1;
      }
    }
    push(@out,$out);
  }
  if ($scalar) {
    return $out[0];
  } else {
    return (@out);
  }
}
use integer;

sub Date_GetPrev {
  my($date,$dow,$today,$hr,$min,$sec)=@_;
  &Date_Init()  if (! $Curr{"InitDone"});
  my($y,$m,$d,$h,$mn,$s,$curr_dow,%dow,$num,$delta,$th,$tm,$ts,
     $adjust,$curr)=();
  $hr="00"   if (defined $hr   &&  $hr eq "0");
  $min="00"  if (defined $min  &&  $min eq "0");
  $sec="00"  if (defined $sec  &&  $sec eq "0");

  if (! &Date_Split($date)) {
    $date=&ParseDateString($date);
    return ""  if (! $date);
  }
  $curr=$date;
  ($y,$m,$d)=( &Date_Split($date) )[0..2];

  if ($dow) {
    $curr_dow=&Date_DayOfWeek($m,$d,$y);
    %dow=%{ $Lang{"WeekH"} };
    if (&IsInt($dow)) {
      return ""  if ($dow<1  ||  $dow>7);
    } else {
      return ""  if (! exists $dow{lc($dow)});
      $dow=$dow{lc($dow)};
    }
    if ($dow == $curr_dow) {
      $date=&DateCalc_DateDelta($date,"-0:0:1:0:0:0:0")  if (! $today);
      $adjust=1  if ($today==2);
    } else {
      $dow -= 7  if ($dow>$curr_dow); # make sure previous day is less
      $num = $curr_dow - $dow;
      $date=&DateCalc_DateDelta($date,"-0:0:0:$num:0:0:0");
    }
    $date=&Date_SetTime($date,$hr,$min,$sec)  if (defined $hr);
    $date=&DateCalc_DateDelta($date,"-0:0:1:0:0:0:0")
      if ($adjust  &&  &Date_Cmp($date,$curr)>0);

  } else {
    ($h,$mn,$s)=( &Date_Split($date) )[3..5];
    ($th,$tm,$ts)=&Date_ParseTime($hr,$min,$sec);
    if ($hr) {
      ($hr,$min,$sec)=($th,$tm,$ts);
      $delta="-0:0:0:1:0:0:0";
    } elsif ($min) {
      ($hr,$min,$sec)=($h,$tm,$ts);
      $delta="-0:0:0:0:1:0:0";
    } elsif ($sec) {
      ($hr,$min,$sec)=($h,$mn,$ts);
      $delta="-0:0:0:0:0:1:0";
    } else {
      confess "ERROR: invalid arguments in Date_GetPrev.\n";
    }

    $d=&Date_SetTime($date,$hr,$min,$sec);
    if ($today) {
      $d=&DateCalc_DateDelta($d,$delta)  if (&Date_Cmp($d,$date)>0);
    } else {
      $d=&DateCalc_DateDelta($d,$delta)  if (&Date_Cmp($d,$date)>=0);
    }
    $date=$d;
  }
  return $date;
}

sub Date_GetNext {
  my($date,$dow,$today,$hr,$min,$sec)=@_;
  &Date_Init()  if (! $Curr{"InitDone"});
  my($y,$m,$d,$h,$mn,$s,$curr_dow,%dow,$num,$delta,$th,$tm,$ts,
     $adjust,$curr)=();
  $hr="00"   if (defined $hr   &&  $hr eq "0");
  $min="00"  if (defined $min  &&  $min eq "0");
  $sec="00"  if (defined $sec  &&  $sec eq "0");

  if (! &Date_Split($date)) {
    $date=&ParseDateString($date);
    return ""  if (! $date);
  }
  $curr=$date;
  ($y,$m,$d)=( &Date_Split($date) )[0..2];

  if ($dow) {
    $curr_dow=&Date_DayOfWeek($m,$d,$y);
    %dow=%{ $Lang{"WeekH"} };
    if (&IsInt($dow)) {
      return ""  if ($dow<1  ||  $dow>7);
    } else {
      return ""  if (! exists $dow{lc($dow)});
      $dow=$dow{lc($dow)};
    }
    if ($dow == $curr_dow) {
      $date=&DateCalc_DateDelta($date,"+0:0:1:0:0:0:0")  if (! $today);
      $adjust=1  if ($today==2);
    } else {
      $curr_dow -= 7  if ($curr_dow>$dow); # make sure next date is greater
      $num = $dow - $curr_dow;
      $date=&DateCalc_DateDelta($date,"+0:0:0:$num:0:0:0");
    }
    $date=&Date_SetTime($date,$hr,$min,$sec)  if (defined $hr);
    $date=&DateCalc_DateDelta($date,"+0:0:1:0:0:0:0")
      if ($adjust  &&  &Date_Cmp($date,$curr)<0);

  } else {
    ($h,$mn,$s)=( &Date_Split($date) )[3..5];
    ($th,$tm,$ts)=&Date_ParseTime($hr,$min,$sec);
    if ($hr) {
      ($hr,$min,$sec)=($th,$tm,$ts);
      $delta="+0:0:0:1:0:0:0";
    } elsif ($min) {
      ($hr,$min,$sec)=($h,$tm,$ts);
      $delta="+0:0:0:0:1:0:0";
    } elsif ($sec) {
      ($hr,$min,$sec)=($h,$mn,$ts);
      $delta="+0:0:0:0:0:1:0";
    } else {
      confess "ERROR: invalid arguments in Date_GetNext.\n";
    }

    $d=&Date_SetTime($date,$hr,$min,$sec);
    if ($today) {
      $d=&DateCalc_DateDelta($d,$delta)  if (&Date_Cmp($d,$date)<0);
    } else {
      $d=&DateCalc_DateDelta($d,$delta)  if (&Date_Cmp($d,$date)<1);
    }
    $date=$d;
  }

  return $date;
}

###
# NOTE: The following routines may be called in the routines below with very
#       little time penalty.
###
sub Date_SetTime {
  my($date,$h,$mn,$s)=@_;
  &Date_Init()  if (! $Curr{"InitDone"});
  my($y,$m,$d)=();

  if (! &Date_Split($date)) {
    $date=&ParseDateString($date);
    return ""  if (! $date);
  }

  ($y,$m,$d)=( &Date_Split($date) )[0..2];
  ($h,$mn,$s)=&Date_ParseTime($h,$mn,$s);

  my($ampm,$wk);
  return ""  if (&Date_DateCheck(\$y,\$m,\$d,\$h,\$mn,\$s,\$ampm,\$wk));
  &Date_Join($y,$m,$d,$h,$mn,$s);
}

sub Date_SetDateField {
  my($date,$field,$val,$nocheck)=@_;
  my($y,$m,$d,$h,$mn,$s)=();
  $nocheck=0  if (! defined $nocheck);

  ($y,$m,$d,$h,$mn,$s)=&Date_Split($date);

  if (! $y) {
    $date=&ParseDateString($date);
    return "" if (! $date);
    ($y,$m,$d,$h,$mn,$s)=&Date_Split($date);
  }

  if      (lc($field) eq "y") {
    $y=$val;
  } elsif (lc($field) eq "m") {
    $m=$val;
  } elsif (lc($field) eq "d") {
    $d=$val;
  } elsif (lc($field) eq "h") {
    $h=$val;
  } elsif (lc($field) eq "mn") {
    $mn=$val;
  } elsif (lc($field) eq "s") {
    $s=$val;
  } else {
    confess "ERROR: Date_SetDateField: invalid field: $field\n";
  }

  $date=&Date_Join($y,$m,$d,$h,$mn,$s);
  return $date  if ($nocheck  ||  &Date_Split($date));
  return "";
}

########################################################################
# OTHER SUBROUTINES
########################################################################
# NOTE: These routines should not call any of the routines above as
#       there will be a severe time penalty (and the possibility of
#       infinite recursion).  The last couple routines above are
#       exceptions.
# NOTE: Date_Init is a special case.  It should be called (conditionally)
#       in every routine that uses any variable from the Date::Manip
#       namespace.
########################################################################

sub Date_DaysInMonth {
  my($m,$y)=@_;
  $y=&Date_FixYear($y)  if (length($y)!=4);
  my(@d_in_m)=(0,31,28,31,30,31,30,31,31,30,31,30,31);
  $d_in_m[2]=29  if (&Date_LeapYear($y));
  return $d_in_m[$m];
}

sub Date_DayOfWeek {
  my($m,$d,$y)=@_;
  $y=&Date_FixYear($y)  if (length($y)!=4);
  my($dayofweek,$dec31)=();

  $dec31=5;                     # Dec 31, 1BC was Friday
  $dayofweek=(&Date_DaysSince1BC($m,$d,$y)+$dec31) % 7;
  $dayofweek=7  if ($dayofweek==0);
  return $dayofweek;
}

# Can't be in "use integer" because the numbers are too big.
no integer;
sub Date_SecsSince1970 {
  my($y,$m,$d,$h,$mn,$s)=@_;
  $y=&Date_FixYear($y)  if (length($y)!=4);
  my($sec_now,$sec_70)=();
  $sec_now=(&Date_DaysSince1BC($m,$d,$y)-1)*24*3600 + $h*3600 + $mn*60 + $s;
# $sec_70 =(&Date_DaysSince1BC(1,1,1970)-1)*24*3600;
  $sec_70 =62167219200;
  return ($sec_now-$sec_70);
}

sub Date_SecsSince1970GMT {
  my($y,$m,$d,$h,$mn,$s)=@_;
  &Date_Init()  if (! $Curr{"InitDone"});
  $y=&Date_FixYear($y)  if (length($y)!=4);

  my($sec)=&Date_SecsSince1970($y,$m,$d,$h,$mn,$s);
  return $sec   if ($Cnf{"ConvTZ"} eq "IGNORE");

  my($tz)=$Cnf{"ConvTZ"};
  $tz=$Cnf{"TZ"}  if (! $tz);
  $tz=$Zone{"n2o"}{lc($tz)}  if ($tz !~ /^[+-]\d{4}$/);

  my($tzs)=1;
  $tzs=-1 if ($tz<0);
  $tz=~/.(..)(..)/;
  my($tzh,$tzm)=($1,$2);
  $sec - $tzs*($tzh*3600+$tzm*60);
}
use integer;

sub Date_DaysSince1BC {
  my($m,$d,$y)=@_;
  $y=&Date_FixYear($y)  if (length($y)!=4);
  my($Ny,$N4,$N100,$N400,$dayofyear,$days)=();
  my($cc,$yy)=();

  $y=~ /(\d{2})(\d{2})/;
  ($cc,$yy)=($1,$2);

  # Number of full years since Dec 31, 1BC (counting the year 0000).
  $Ny=$y;

  # Number of full 4th years (incl. 0000) since Dec 31, 1BC
  $N4=($Ny-1)/4 + 1;
  $N4=0         if ($y==0);

  # Number of full 100th years (incl. 0000)
  $N100=$cc + 1;
  $N100--       if ($yy==0);
  $N100=0       if ($y==0);

  # Number of full 400th years (incl. 0000)
  $N400=($N100-1)/4 + 1;
  $N400=0       if ($y==0);

  $dayofyear=&Date_DayOfYear($m,$d,$y);
  $days= $Ny*365 + $N4 - $N100 + $N400 + $dayofyear;

  return $days;
}

sub Date_DayOfYear {
  my($m,$d,$y)=@_;
  $y=&Date_FixYear($y)  if (length($y)!=4);
  # DinM    = (31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31)
  my(@days) = ( 0, 31, 59, 90,120,151,181,212,243,273,304,334,365);
  my($ly)=0;
  $ly=1  if ($m>2 && &Date_LeapYear($y));
  return ($days[$m-1]+$d+$ly);
}

sub Date_DaysInYear {
  my($y)=@_;
  $y=&Date_FixYear($y)  if (length($y)!=4);
  return 366  if (&Date_LeapYear($y));
  return 365;
}

sub Date_WeekOfYear {
  my($m,$d,$y,$f)=@_;
  &Date_Init()  if (! $Curr{"InitDone"});
  $y=&Date_FixYear($y)  if (length($y)!=4);

  my($day,$dow,$doy)=();
  $doy=&Date_DayOfYear($m,$d,$y);

  # The current DayOfYear and DayOfWeek
  if ($Cnf{"Jan1Week1"}) {
    $day=1;
  } else {
    $day=4;
  }
  $dow=&Date_DayOfWeek(1,$day,$y);

  # Move back to the first day of week 1.
  $f-=7  if ($f>$dow);
  $day-= ($dow-$f);

  return 0  if ($day>$doy);      # Day is in last week of previous year
  return (($doy-$day)/7 + 1);
}

sub Date_LeapYear {
  my($y)=@_;
  $y=&Date_FixYear($y)  if (length($y)!=4);
  return 0 unless $y % 4 == 0;
  return 1 unless $y % 100 == 0;
  return 0 unless $y % 400 == 0;
  return 1;
}

sub Date_DaySuffix {
  my($d)=@_;
  &Date_Init()  if (! $Curr{"InitDone"});
  return $Lang{"DoML"}[$d-1];
}

sub Date_ConvTZ {
  my($date,$from,$to)=@_;
  &Date_Init()  if (! $Curr{"InitDone"});
  my($gmt)=();

  if (! $from) {

    if (! $to) {
      # TZ -> ConvTZ
      return $date  if ($Cnf{"ConvTZ"} eq "IGNORE" or ! $Cnf{"ConvTZ"});
      $from=$Cnf{"TZ"};
      $to=$Cnf{"ConvTZ"};

    } else {
      # ConvTZ,TZ -> $to
      $from=$Cnf{"ConvTZ"};
      $from=$Cnf{"TZ"}  if (! $from);
    }

  } else {

    if (! $to) {
      # $from -> ConvTZ,TZ
      return $date  if ($Cnf{"ConvTZ"} eq "IGNORE");
      $to=$Cnf{"ConvTZ"};
      $to=$Cnf{"TZ"}  if (! $to);

    } else {
      # $from -> $to
    }
  }

  $to=$Zone{"n2o"}{lc($to)}
    if (exists $Zone{"n2o"}{lc($to)});
  $from=$Zone{"n2o"}{lc($from)}
    if (exists $Zone{"n2o"}{lc($from)});
  $gmt=$Zone{"n2o"}{"gmt"};

  return $date  if ($from !~ /^[+-]\d{4}$/ or $to !~ /^[+-]\d{4}$/);
  return $date  if ($from eq $to);

  my($s1,$h1,$m1,$s2,$h2,$m2,$d,$h,$m,$sign,$delta,$yr,$mon,$sec)=();
  # We're going to try to do the calculation without calling DateCalc.
  ($yr,$mon,$d,$h,$m,$sec)=&Date_Split($date);

  # Convert $date from $from to GMT
  $from=~/([+-])(\d{2})(\d{2})/;
  ($s1,$h1,$m1)=($1,$2,$3);
  $s1= ($s1 eq "-" ? "+" : "-");   # switch sign
  $sign=$s1 . "1";     # + or - 1

  # and from GMT to $to
  $to=~/([+-])(\d{2})(\d{2})/;
  ($s2,$h2,$m2)=($1,$2,$3);

  if ($s1 eq $s2) {
    # Both the same sign
    $m+= $sign*($m1+$m2);
    $h+= $sign*($h1+$h2);
  } else {
    $sign=($s2 eq "-" ? +1 : -1)  if ($h1<$h2  ||  ($h1==$h2 && $m1<$m2));
    $m+= $sign*($m1-$m2);
    $h+= $sign*($h1-$h2);
  }

  if ($m>59) {
    $h+= $m/60;
    $m-= ($m/60)*60;
  } elsif ($m<0) {
    $h+= ($m/60 - 1);
    $m-= ($m/60 - 1)*60;
  }

  if ($h>23) {
    $delta=$h/24;
    $h -= $delta*24;
    if (($d + $delta) > 28) {
      $date=&Date_Join($yr,$mon,$d,$h,$m,$sec);
      return &DateCalc_DateDelta($date,"+0:0:0:$delta:0:0:0");
    }
    $d+= $delta;
  } elsif ($h<0) {
    $delta=-$h/24 + 1;
    $h += $delta*24;
    if (($d - $delta) < 1) {
      $date=&Date_Join($yr,$mon,$d,$h,$m,$sec);
      return &DateCalc_DateDelta($date,"-0:0:0:$delta:0:0:0");
    }
    $d-= $delta;
  }
  return &Date_Join($yr,$mon,$d,$h,$m,$sec);
}

sub Date_TimeZone {
  my($null,$tz,@tz,$std,$dst,$time,$isdst,$tmp,$in)=();
  &Date_Init()  if (! $Curr{"InitDone"});

  # Get timezones from all of the relevant places

  push(@tz,$Cnf{"TZ"})  if (defined $Cnf{"TZ"});  # TZ config var
  push(@tz,$ENV{"TZ"})  if (exists $ENV{"TZ"});   # TZ environ var
  push(@tz,$main::TZ)         if (defined $main::TZ);         # $main::TZ

  if (-s "/etc/TIMEZONE") {                                   # /etc/TIMEZONE
    $in=new IO::File;
    $in->open("/etc/TIMEZONE","r");
    while (! eof($in)) {
      $tmp=<$in>;
      if ($tmp =~ /^TZ\s*=\s*(.*?)\s*$/) {
        push(@tz,$1);
        last;
      }
    }
    $in->close;
  }

  if (-s "/etc/timezone") {                                   # /etc/timezone
    $in=new IO::File;
    $in->open("/etc/timezone","r");
    while (! eof($in)) {
      $tmp=<$in>;
      next  if ($tmp =~ /^\s*\043/);
      chomp($tmp);
      if ($tz =~ /^\s*(.*?)\s*$/) {
        push(@tz,$1);
        last;
      }
    }
    $in->close;
  }

  # Now parse each one to find the first valid one.
  foreach $tz (@tz) {
    return uc($tz)
      if (defined $Zone{"n2o"}{lc($tz)} or $tz=~/^[+-]\d{4}/);

    # Handle US/Eastern format
    if ($tz =~ /^$Zone{"tzones"}$/i) {
      $tmp=lc $1;
      $tz=$Zone{"tz2z"}{$tmp};
    }

    # Handle STD#DST# format (and STD-#DST-# formats)
    if ($tz =~ /^([a-z]+)-?\d([a-z]+)-?\d?$/i) {
      ($std,$dst)=($1,$2);
      next  if (! defined $Zone{"n2o"}{lc($std)} or
                ! defined $Zone{"n2o"}{lc($dst)});
      $time = time();
      ($null,$null,$null,$null,$null,$null,$null,$null,$isdst) =
        localtime($time);
      return uc($dst)  if ($isdst);
      return uc($std);
    }
  }

  confess "ERROR: Date::Manip unable to determine TimeZone.\n";
}

# &Date_NthDayOfYear($y,$n);
#   Returns a list of (YYYY,MM,DD,HH,MM,SS) for the Nth day of the year.
sub Date_NthDayOfYear {
  no integer;
  my($y,$n)=@_;
  $y=$Curr{"Y"}  if (! $y);
  $n=1       if (! defined $n  or  $n eq "");
  $n+=0;     # to turn 023 into 23
  $y=&Date_FixYear($y)  if (length($y)<4);
  my $leap=&Date_LeapYear($y);
  return ()  if ($n<1);
  return ()  if ($n >= ($leap ? 367 : 366));

  my(@d_in_m)=(31,28,31,30,31,30,31,31,30,31,30,31);
  $d_in_m[1]=29  if ($leap);

  # Calculate the hours, minutes, and seconds into the day.
  my $remain=($n - int($n))*24;
  my $h=int($remain);
  $remain=($remain - $h)*60;
  my $mn=int($remain);
  $remain=($remain - $mn)*60;
  my $s=$remain;

  # Calculate the month and the day.
  my($m,$d)=(0,0);
  while ($n>0) {
    $m++;
    if ($n<=$d_in_m[0]) {
      $d=int($n);
      $n=0;
    } else {
      $n-= $d_in_m[0];
      shift(@d_in_m);
    }
  }

  ($y,$m,$d,$h,$mn,$s);
}

########################################################################
# NOT FOR EXPORT
########################################################################

# This is used in Date_Init to fill in a hash based on international
# data.  It takes a list of keys and values and returns both a hash
# with these values and a regular expression of keys.
#
# IN:
#   $data   = [ key1 val1 key2 val2 ... ]
#   $opts   = lc     : lowercase the keys in the regexp
#             sort   : sort (by length) the keys in the regexp
#             back   : create a regexp with a back reference
#             escape : escape all strings in the regexp
#
# OUT:
#   $regexp = '(?:key1|key2|...)'
#   $hash   = { key1=>val1 key2=>val2 ... }

sub Date_InitHash {
  my($data,$regexp,$opts,$hash)=@_;
  my(@data)=@$data;
  my($key,$val,@list)=();

  # Parse the options
  my($lc,$sort,$back,$escape)=(0,0,0,0);
  $lc=1     if ($opts =~ /lc/i);
  $sort=1   if ($opts =~ /sort/i);
  $back=1   if ($opts =~ /back/i);
  $escape=1 if ($opts =~ /escape/i);

  # Create the hash
  while (@data) {
    ($key,$val,@data)=@data;
    $key=lc($key)  if ($lc);
    $$hash{$key}=$val;
  }

  # Create the regular expression
  if ($regexp) {
    @list=keys(%$hash);
    @list=sort sortByLength(@list)  if ($sort);
    if ($escape) {
      foreach $val (@list) {
        $val="\Q$val\E";
      }
    }
    if ($back) {
      $$regexp="(" . join("|",@list) . ")";
    } else {
      $$regexp="(?:" . join("|",@list) . ")";
    }
  }
}

# This is used in Date_Init to fill in regular expressions, lists, and
# hashes based on international data.  It takes a list of lists which have
# to be stored as regular expressions (to find any element in the list),
# lists, and hashes (indicating the location in the lists).
#
# IN:
#   $data   = [ [ [ valA1 valA2 ... ][ valA1' valA2' ... ] ... ]
#               [ [ valB1 valB2 ... ][ valB1' valB2' ... ] ... ]
#               ...
#               [ [ valZ1 valZ2 ... ] [valZ1' valZ1' ... ] ... ] ]
#   $lists  = [ \@listA \@listB ... \@listZ ]
#   $opts   = lc     : lowercase the values in the regexp
#             sort   : sort (by length) the values in the regexp
#             back   : create a regexp with a back reference
#             escape : escape all strings in the regexp
#   $hash   = [ \%hash, TYPE ]
#             TYPE 0 : $hash{ valBn=>n-1 }
#             TYPE 1 : $hash{ valBn=>n }
#
# OUT:
#   $regexp = '(?:valA1|valA2|...|valB1|...)'
#   $lists  = [ [ valA1 valA2 ... ]         # only the 1st list (or
#               [ valB1 valB2 ... ] ... ]   # 2nd for int. characters)
#   $hash

sub Date_InitLists {
  my($data,$regexp,$opts,$lists,$hash)=@_;
  my(@data)=@$data;
  my(@lists)=@$lists;
  my($i,@ele,$ele,@list,$j,$tmp)=();

  # Parse the options
  my($lc,$sort,$back,$escape)=(0,0,0,0);
  $lc=1     if ($opts =~ /lc/i);
  $sort=1   if ($opts =~ /sort/i);
  $back=1   if ($opts =~ /back/i);
  $escape=1 if ($opts =~ /escape/i);

  # Set each of the lists
  if (@lists) {
    confess "ERROR: Date_InitLists: lists must be 1 per data\n"
      if ($#lists != $#data);
    for ($i=0; $i<=$#data; $i++) {
      @ele=@{ $data[$i] };
      @{ $lists[$i] } = @{ $ele[0] };
    }
  }

  # Create the hash
  my($hashtype,$hashsave,%hash)=();
  if (@$hash) {
    ($hash,$hashtype)=@$hash;
    $hashsave=1;
  } else {
    $hashtype=0;
    $hashsave=0;
  }
  for ($i=0; $i<=$#data; $i++) {
    @ele=@{ $data[$i] };
    foreach $ele (@ele) {
      @list = @{ $ele };
      for ($j=0; $j<=$#list; $j++) {
        $tmp=$list[$j];
        next  if (! $tmp);
        $tmp=lc($tmp)  if ($lc);
        $hash{$tmp}= $j+$hashtype;
      }
    }
  }
  %$hash = %hash  if ($hashsave);

  # Create the regular expression
  if ($regexp) {
    @list=keys(%hash);
    @list=sort sortByLength(@list)  if ($sort);
    if ($escape) {
      foreach $ele (@list) {
        $ele="\Q$ele\E";
      }
    }
    if ($back) {
      $$regexp="(" . join("|",@list) . ")";
    } else {
      $$regexp="(?:" . join("|",@list) . ")";
    }
  }
}

# This is used in Date_Init to fill in regular expressions and lists based
# on international data.  This takes a list of strings and returns a regular
# expression (to find any one of them).
#
# IN:
#   $data   = [ string1 string2 ... ]
#   $opts   = lc     : lowercase the values in the regexp
#             sort   : sort (by length) the values in the regexp
#             back   : create a regexp with a back reference
#             escape : escape all strings in the regexp
#
# OUT:
#   $regexp = '(string1|string2|...)'

sub Date_InitStrings {
  my($data,$regexp,$opts)=@_;
  my(@list)=@{ $data };

  # Parse the options
  my($lc,$sort,$back,$escape)=(0,0,0,0);
  $lc=1     if ($opts =~ /lc/i);
  $sort=1   if ($opts =~ /sort/i);
  $back=1   if ($opts =~ /back/i);
  $escape=1 if ($opts =~ /escape/i);

  # Create the regular expression
  my($ele)=();
  @list=sort sortByLength(@list)  if ($sort);
  if ($escape) {
    foreach $ele (@list) {
      $ele="\Q$ele\E";
    }
  }
  if ($back) {
    $$regexp="(" . join("|",@list) . ")";
  } else {
    $$regexp="(?:" . join("|",@list) . ")";
  }
  $$regexp=lc($$regexp)  if ($lc);
}

# items is passed in (either as a space separated string, or a reference to
# a list) and a regular expression which matches any one of the items is
# prepared.  The regular expression will be of one of the forms:
#   "(a|b)"       @list not empty, back option included
#   "(?:a|b)"     @list not empty
#   "()"          @list empty,     back option included
#   ""            @list empty
# $options is a string which contains any of the following strings:
#   back     : the regular expression has a backreference
#   opt      : the regular expression is optional and a "?" is appended in
#              the first two forms
#   optws    : the regular expression is optional and may be replaced by
#              whitespace
#   optWs    : the regular expression is optional, but if not present, must
#              be replaced by whitespace
#   sort     : the items in the list are sorted by length (longest first)
#   lc       : the string is lowercased
#   under    : any underscores are converted to spaces
#   pre      : it may be preceded by whitespace
#   Pre      : it must be preceded by whitespace
#   PRE      : it must be preceded by whitespace or the start
#   post     : it may be followed by whitespace
#   Post     : it must be followed by whitespace
#   POST     : it must be followed by whitespace or the end
# Spaces due to pre/post options will not be included in the back reference.
#
# If $array is included, then the elements will also be returned as a list.
# $array is a string which may contain any of the following:
#   keys     : treat the list as a hash and only the keys go into the regexp
#   key0     : treat the list as the values of a hash with keys 0 .. N-1
#   key1     : treat the list as the values of a hash with keys 1 .. N
#   val0     : treat the list as the keys of a hash with values 0 .. N-1
#   val1     : treat the list as the keys of a hash with values 1 .. N

#    &Date_InitLists([$lang{"month_name"},$lang{"month_abb"}],
#             [\$Month,"lc,sort,back"],
#             [\@Month,\@Mon],
#             [\%Month,1]);

# This is used in Date_Init to prepare regular expressions.  A list of
# items is passed in (either as a space separated string, or a reference to
# a list) and a regular expression which matches any one of the items is
# prepared.  The regular expression will be of one of the forms:
#   "(a|b)"       @list not empty, back option included
#   "(?:a|b)"     @list not empty
#   "()"          @list empty,     back option included
#   ""            @list empty
# $options is a string which contains any of the following strings:
#   back     : the regular expression has a backreference
#   opt      : the regular expression is optional and a "?" is appended in
#              the first two forms
#   optws    : the regular expression is optional and may be replaced by
#              whitespace
#   optWs    : the regular expression is optional, but if not present, must
#              be replaced by whitespace
#   sort     : the items in the list are sorted by length (longest first)
#   lc       : the string is lowercased
#   under    : any underscores are converted to spaces
#   pre      : it may be preceded by whitespace
#   Pre      : it must be preceded by whitespace
#   PRE      : it must be preceded by whitespace or the start
#   post     : it may be followed by whitespace
#   Post     : it must be followed by whitespace
#   POST     : it must be followed by whitespace or the end
# Spaces due to pre/post options will not be included in the back reference.
#
# If $array is included, then the elements will also be returned as a list.
# $array is a string which may contain any of the following:
#   keys     : treat the list as a hash and only the keys go into the regexp
#   key0     : treat the list as the values of a hash with keys 0 .. N-1
#   key1     : treat the list as the values of a hash with keys 1 .. N
#   val0     : treat the list as the keys of a hash with values 0 .. N-1
#   val1     : treat the list as the keys of a hash with values 1 .. N
sub Date_Regexp {
  my($list,$options,$array)=@_;
  my(@list,$ret,%hash,$i)=();
  local($_)=();
  $options=""  if (! defined $options);
  $array=""    if (! defined $array);

  my($sort,$lc,$under)=(0,0,0);
  $sort =1  if ($options =~ /sort/i);
  $lc   =1  if ($options =~ /lc/i);
  $under=1  if ($options =~ /under/i);
  my($back,$opt,$pre,$post,$ws)=("?:","","","","");
  $back =""          if ($options =~ /back/i);
  $opt  ="?"         if ($options =~ /opt/i);
  $pre  ='\s*'       if ($options =~ /pre/);
  $pre  ='\s+'       if ($options =~ /Pre/);
  $pre  ='(?:\s+|^)' if ($options =~ /PRE/);
  $post ='\s*'       if ($options =~ /post/);
  $post ='\s+'       if ($options =~ /Post/);
  $post ='(?:$|\s+)' if ($options =~ /POST/);
  $ws   ='\s*'       if ($options =~ /optws/);
  $ws   ='\s+'       if ($options =~ /optws/);

  my($hash,$keys,$key0,$key1,$val0,$val1)=(0,0,0,0,0,0);
  $keys =1     if ($array =~ /keys/i);
  $key0 =1     if ($array =~ /key0/i);
  $key1 =1     if ($array =~ /key1/i);
  $val0 =1     if ($array =~ /val0/i);
  $val1 =1     if ($array =~ /val1/i);
  $hash =1     if ($keys or $key0 or $key1 or $val0 or $val1);

  my($ref)=ref $list;
  if (! $ref) {
    $list =~ s/\s*$//;
    $list =~ s/^\s*//;
    $list =~ s/\s+/&&&/g;
  } elsif ($ref eq "ARRAY") {
    $list = join("&&&",@$list);
  } else {
    confess "ERROR: Date_Regexp.\n";
  }

  if (! $list) {
    if ($back eq "") {
      return "()";
    } else {
      return "";
    }
  }

  $list=lc($list)  if ($lc);
  $list=~ s/_/ /g  if ($under);
  @list=split(/&&&/,$list);
  if ($keys) {
    %hash=@list;
    @list=keys %hash;
  } elsif ($key0 or $key1 or $val0 or $val1) {
    $i=0;
    $i=1  if ($key1 or $val1);
    if ($key0 or $key1) {
      %hash= map { $_,$i++ } @list;
    } else {
      %hash= map { $i++,$_ } @list;
    }
  }
  @list=sort sortByLength(@list)  if ($sort);

  $ret="($back" . join("|",@list) . ")";
  $ret="(?:$pre$ret$post)"  if ($pre or $post);
  $ret.=$opt;
  $ret="(?:$ret|$ws)"  if ($ws);

  if ($array and $hash) {
    return ($ret,%hash);
  } elsif ($array) {
    return ($ret,@list);
  } else {
    return $ret;
  }
}

# This will produce a delta with the correct number of signs.  At most two
# signs will be in it normally (one before the year, and one in front of
# the day), but if appropriate, signs will be in front of all elements.
# Also, as many of the signs will be equivalent as possible.
sub Delta_Normalize {
  my($delta)=@_;
  return "" if (! $delta);
  return "+0:+0:+0:+0:+0:+0:+0"
    if ($delta =~ /^([+-]?0+:){6}[+-]?0+$/ and $Cnf{"DeltaSigns"});
  return "+0:0:0:0:0:0:0" if ($delta =~ /^([+-]?0+:){6}[+-]?0+$/);

  my($tmp,$sign1,$sign2,$len)=();

  # Calculate the length of the day in minutes
  $len=24*60;

  # We have to get the sign of every component explicitely so that a "-0"
  # or "+0" doesn't get lost by treating it numerically (i.e. "-0:0:2" must
  # be a negative delta).

  my($y,$mon,$w,$d,$h,$m,$s)=&Delta_Split($delta);

  # We need to make sure that the signs of all parts of a delta are the
  # same.  The easiest way to do this is to convert all of the large
  # components to the smallest ones, then convert the smaller components
  # back to the larger ones.

  # Do the year/month part

  $mon += $y*12;                         # convert y to m
  $sign1="+";
  if ($mon<0) {
    $mon *= -1;
    $sign1="-";
  }

  $y    = $mon/12;                       # convert m to y
  $mon -= $y*12;

  $y=0    if ($y eq "-0");               # get around silly -0 problem
  $mon=0  if ($mon eq "-0");

  # Do the wk/day/hour/min/sec part

  {
    # Unfortunately, $s is overflowing for dates more than ~70 years
    # apart.
    no integer;

    $s += ($d+7*$w)*$len*60 + $h*3600 + $m*60; # convert w/d/h/m to s
    $sign2="+";
    if ($s<0) {
      $s*=-1;
      $sign2="-";
    }

    $m  = int($s/60);                    # convert s to m
    $s -= $m*60;
    $d  = int($m/$len);                  # convert m to d
    $m -= $d*$len;

    # The rest should be fine.
  }
  $h  = $m/60;                           # convert m to h
  $m -= $h*60;
  $w  = $d/7;                            # convert d to w
  $d -= $w*7;

  $w=0    if ($w eq "-0");               # get around silly -0 problem
  $d=0    if ($d eq "-0");
  $h=0    if ($h eq "-0");
  $m=0    if ($m eq "-0");
  $s=0    if ($s eq "-0");

  # Only include two signs if necessary
  $sign1=$sign2  if ($y==0 and $mon==0);
  $sign2=$sign1  if ($w==0 and $d==0 and $h==0 and $m==0 and $s==0);
  $sign2=""  if ($sign1 eq $sign2  and  ! $Cnf{"DeltaSigns"});

  if ($Cnf{"DeltaSigns"}) {
    return "$sign1$y:$sign1$mon:$sign2$w:$sign2$d:$sign2$h:$sign2$m:$sign2$s";
  } else {
    return "$sign1$y:$mon:$sign2$w:$d:$h:$m:$s";
  }
}

# This checks a delta to make sure it is valid.  If it is, it splits
# it and returns the elements with a sign on each.  The 2nd argument
# specifies the default sign.  Blank elements are set to 0.  If the
# third element is non-nil, exactly 7 elements must be included.
sub Delta_Split {
  my($delta,$sign,$exact)=@_;
  my(@delta)=split(/:/,$delta);
  return ()  if ($exact  and $#delta != 6);
  my($i)=();
  $sign="+"  if (! defined $sign);
  for ($i=0; $i<=$#delta; $i++) {
    $delta[$i]="0"  if (! $delta[$i]);
    return ()  if ($delta[$i] !~ /^[+-]?\d+$/);
    $sign = ($delta[$i] =~ s/^([+-])// ? $1 : $sign);
    $delta[$i] = $sign.$delta[$i];
  }
  @delta;
}

# Reads up to 3 arguments.  $h may contain the time in any international
# format.  Any empty elements are set to 0.
sub Date_ParseTime {
  my($h,$m,$s)=@_;
  my($t)=&CheckTime();

  if (defined $h  and  $h =~ /$t/) {
    $h=$1;
    $m=$2;
    $s=$3   if (defined $3);
  }
  $h="00"  if (! defined $h);
  $m="00"  if (! defined $m);
  $s="00"  if (! defined $s);

  ($h,$m,$s);
}

# Forms a date with the 6 elements passed in (all of which must be defined).
# No check as to validity is made.
sub Date_Join {
  my($y,$m,$d,$h,$mn,$s)=@_;
  my($ym,$md,$dh,$hmn,$mns)=();

  if      ($Cnf{"Internal"} == 0) {
    $ym=$md=$dh="";
    $hmn=$mns=":";

  } elsif ($Cnf{"Internal"} == 1) {
    $ym=$md=$dh=$hmn=$mns="";

  } elsif ($Cnf{"Internal"} == 2) {
    $ym=$md="-";
    $dh=" ";
    $hmn=$mns=":";

  } else {
    confess "ERROR: Invalid internal format in Date_Join.\n";
  }
  $m="0$m"    if (length($m)==1);
  $d="0$d"    if (length($d)==1);
  $h="0$h"    if (length($h)==1);
  $mn="0$mn"  if (length($mn)==1);
  $s="0$s"    if (length($s)==1);
  "$y$ym$m$md$d$dh$h$hmn$mn$mns$s";
}

# This returns a regexp with 1/2 hours is
sub CheckTime {
  my($h)='(?:0?[0-9]|1[0-9]|2[0-3])';
  my($h2)='(?:0[0-9]|1[0-9]|2[0-3])';
  my($m)='[0-5][0-9]';
  my($s)=$m;
  my($hm)="(?:". $Lang{"SepHM"} ."|:)";
  my($ms)="(?:". $Lang{"SepMS"} ."|:)";
  my($ss)=$Lang{"SepSS"};
  my($t)="^($h)$hm($m)(?:$ms($s)(?:$ss\\d+)?)?\$";
  return $t;
}

# This checks a date.  If it is valid, it splits it and returns the elements.
# If no date is passed in, it returns a regular expression for the date.
sub Date_Split {
  my($date)=@_;
  my($ym,$md,$dh,$hmn,$mns)=();
  my($y)='(\d{4})';
  my($m)='(0[1-9]|1[0-2])';
  my($d)='(0[1-9]|[1-2][0-9]|3[0-1])';
  my($h)='([0-1][0-9]|2[0-3])';
  my($mn)='([0-5][0-9])';
  my($s)=$mn;

  if      ($Cnf{"Internal"} == 0) {
    $ym=$md=$dh="";
    $hmn=$mns=":";

  } elsif ($Cnf{"Internal"} == 1) {
    $ym=$md=$dh=$hmn=$mns="";

  } elsif ($Cnf{"Internal"} == 2) {
    $ym=$md="-";
    $dh=" ";
    $hmn=$mns=":";

  } else {
    confess "ERROR: Invalid internal format in Date_Split.\n";
  }

  my($t)="^$y$ym$m$md$d$dh$h$hmn$mn$mns$s\$";
  return $t  if ($date eq "");

  if ($date =~ /$t/) {
    ($y,$m,$d,$h,$mn,$s)=($1,$2,$3,$4,$5,$6);
    my(@d_in_m)=(0,31,28,31,30,31,30,31,31,30,31,30,31);
    $d_in_m[2]=29  if (&Date_LeapYear($y));
    return ()  if ($d>$d_in_m[$m]);
    return ($y,$m,$d,$h,$mn,$s);
  }
  return ();
}

sub DateCalc_DateDate {
  my($D1,$D2)=@_;
  my(@d_in_m)=(0,31,28,31,30,31,30,31,31,30,31,30,31);

  my($y1,$m1,$d1,$h1,$mn1,$s1)=&Date_Split($D1);
  my($y2,$m2,$d2,$h2,$mn2,$s2)=&Date_Split($D2);
  my($i,@delta,$d,$delta,$y)=();

  # form the delta for hour/min/sec
  $delta[4]=$h2-$h1;
  $delta[5]=$mn2-$mn1;
  $delta[6]=$s2-$s1;

  # form the delta for yr/mon/day
  $delta[0]=$delta[1]=0;
  $d=0;
  if ($y2>$y1) {
    $d=&Date_DaysInYear($y1) - &Date_DayOfYear($m1,$d1,$y1);
    $d+=&Date_DayOfYear($m2,$d2,$y2);
    for ($y=$y1+1; $y<$y2; $y++) {
      $d+= &Date_DaysInYear($y);
    }
  } elsif ($y2<$y1) {
    $d=&Date_DaysInYear($y2) - &Date_DayOfYear($m2,$d2,$y2);
    $d+=&Date_DayOfYear($m1,$d1,$y1);
    for ($y=$y2+1; $y<$y1; $y++) {
      $d+= &Date_DaysInYear($y);
    }
    $d *= -1;
  } else {
    $d=&Date_DayOfYear($m2,$d2,$y2) - &Date_DayOfYear($m1,$d1,$y1);
  }
  $delta[2]=0;
  $delta[3]=$d;

  for ($i=0; $i<7; $i++) {
    $delta[$i]="+".$delta[$i]  if ($delta[$i]>=0);
  }

  $delta=join(":",@delta);
  $delta=&Delta_Normalize($delta,0);
  return $delta;

  my($date1,$date2)=($D1,$D2);
  my($tmp,$sign,@tmp)=();

  # make sure date1 comes before date2
  if (&Date_Cmp($date1,$date2)>0) {
    $sign="-";
    $tmp=$date1;
    $date1=$date2;
    $date2=$tmp;
  } else {
    $sign="+";
  }
  if (&Date_Cmp($date1,$date2)==0) {
    return "+0:+0:+0:+0:+0:+0:+0"  if ($Cnf{"DeltaSigns"});
    return "+0:0:0:0:0:0:0";
  }

  my($y1,$m1,$d1,$h1,$mn1,$s1)=&Date_Split($date1);
  my($y2,$m2,$d2,$h2,$mn2,$s2)=&Date_Split($date2);
  my($dy,$dm,$dw,$dd,$dh,$dmn,$ds,$ddd)=(0,0,0,0,0,0,0,0);

  # Do days
  ($y1,$m1,$d1)=( &Date_Split($date1) )[0..2];
  $dd=0;
  # If we're jumping across months, set $d1 to the first of the next month
  # (or possibly the 0th of next month which is equivalent to the last day
  # of this month)
  if ($m1!=$m2) {
    $d_in_m[2]=29  if (&Date_LeapYear($y1));
    $dd=$d_in_m[$m1]-$d1+1;
    $d1=1;
    $tmp=&DateCalc_DateDelta($date1,"+0:0:0:$dd:0:0:0");
    if (&Date_Cmp($tmp,$date2)>0) {
      $dd--;
      $d1--;
      $tmp=&DateCalc_DateDelta($date1,"+0:0:0:$dd:0:0:0");
    }
    $date1=$tmp;
  }

  $ddd=0;
  if ($d1<$d2) {
    $ddd=$d2-$d1;
    $tmp=&DateCalc_DateDelta($date1,"+0:0:0:$ddd:0:0:0");
    if (&Date_Cmp($tmp,$date2)>0) {
      $ddd--;
      $tmp=&DateCalc_DateDelta($date1,"+0:0:0:$ddd:0:0:0");
    }
    $date1=$tmp;
  }
  $dd+=$ddd;

  $d1=( &Date_Split($date1) )[2];
  $dh=$dmn=$ds=0;

  # Hours, minutes, seconds
  $tmp=&DateCalc_DateDate($date1,$date2,0);
  @tmp=&Delta_Split($tmp);
  $dh  += $tmp[4];
  $dmn += $tmp[5];
  $ds  += $tmp[6];

  $tmp="$sign$dy:$dm:0:$dd:$dh:$dmn:$ds";
  &Delta_Normalize($tmp);
}

sub DateCalc_DeltaDelta {
  my($D1,$D2)=@_;
  my(@delta1,@delta2,$i,$delta,@delta)=();

  @delta1=&Delta_Split($D1);
  @delta2=&Delta_Split($D2);
  for ($i=0; $i<7; $i++) {
    $delta[$i]=$delta1[$i]+$delta2[$i];
    $delta[$i]="+".$delta[$i]  if ($delta[$i]>=0);
  }

  $delta=join(":",@delta);
  $delta=&Delta_Normalize($delta);
  return $delta;
}

sub DateCalc_DateDelta {
  my($D1,$D2)=@_;
  my($date)=();
  my(@d_in_m)=(0,31,28,31,30,31,30,31,31,30,31,30,31);
  my($h1,$m1,$h2,$m2,$len,$hh,$mm)=();

  # Date, delta
  my($y,$m,$d,$h,$mn,$s)=&Date_Split($D1);
  my($dy,$dm,$dw,$dd,$dh,$dmn,$ds)=&Delta_Split($D2);

  # do the month/year part
  $y+=$dy;
  &ModuloAddition(-12,$dm,\$m,\$y);   # -12 means 1-12 instead of 0-11
  $d_in_m[2]=29  if (&Date_LeapYear($y));

  # if we have gone past the last day of a month, move the date back to
  # the last day of the month
  if ($d>$d_in_m[$m]) {
    $d=$d_in_m[$m];
  }

  # do the week part
  $dd += $dw*7;

  # seconds, minutes, hours
  &ModuloAddition(60,$ds,\$s,\$mn);
  &ModuloAddition(60,$dmn,\$mn,\$h);
  &ModuloAddition(24,$dh,\$h,\$d);

  # If we have just gone past the last day of the month, we need to make
  # up for this:
  if ($d>$d_in_m[$m]) {
    $dd+= $d-$d_in_m[$m];
    $d=$d_in_m[$m];
  }

  # days
  $d_in_m[2]=29  if (&Date_LeapYear($y));
  $d=$d_in_m[$m]  if ($d>$d_in_m[$m]);
  $d += $dd;
  while ($d<1) {
    $m--;
    if ($m==0) {
      $m=12;
      $y--;
      if (&Date_LeapYear($y)) {
        $d_in_m[2]=29;
      } else {
        $d_in_m[2]=28;
      }
    }
    $d += $d_in_m[$m];
  }
  while ($d>$d_in_m[$m]) {
    $d -= $d_in_m[$m];
    $m++;
    if ($m==13) {
      $m=1;
      $y++;
      if (&Date_LeapYear($y)) {
        $d_in_m[2]=29;
      } else {
        $d_in_m[2]=28;
      }
    }
  }

  if ($y<0 or $y>9999) {
    return;
  }
  &Date_Join($y,$m,$d,$h,$mn,$s);
}

# $flag=&Date_TimeCheck(\$h,\$mn,\$s,\$ampm);
#   Returns 1 if any of the fields are bad.  All fields are optional, and
#   all possible checks are done on the data.  If a field is not passed in,
#   it is set to default values.  If data is missing, appropriate defaults
#   are supplied.
sub Date_TimeCheck {
  my($h,$mn,$s,$ampm)=@_;
  my($tmp1,$tmp2,$tmp3)=();

  $$h=""     if (! defined $$h);
  $$mn=""    if (! defined $$mn);
  $$s=""     if (! defined $$s);
  $$ampm=""  if (! defined $$ampm);
  $$ampm=uc($$ampm)  if ($$ampm);

  # Check hour
  $tmp1=$Lang{"AmPm"};
  $tmp2="";
  if ($$ampm =~ /^$tmp1$/i) {
    $tmp3=$Lang{"AM"};
    $tmp2="AM"  if ($$ampm =~ /^$tmp3$/i);
    $tmp3=$Lang{"PM"};
    $tmp2="PM"  if ($$ampm =~ /^$tmp3$/i);
  } elsif ($$ampm) {
    return 1;
  }
  if ($tmp2 eq "AM" || $tmp2 eq "PM") {
    $$h="0$$h"    if (length($$h)==1);
    return 1      if ($$h<1 || $$h>12);
    $$h="00"      if ($tmp2 eq "AM"  and  $$h==12);
    $$h += 12     if ($tmp2 eq "PM"  and  $$h!=12);
  } else {
    $$h="00"      if ($$h eq "");
    $$h="0$$h"    if (length($$h)==1);
    return 1      if (! &IsInt($$h,0,23));
    $tmp2="AM"    if ($$h<12);
    $tmp2="PM"    if ($$h>=12);
  }
  $$ampm=$Lang{"AMstr"};
  $$ampm=$Lang{"PMstr"}  if ($tmp2 eq "PM");

  # Check minutes
  $$mn="00"       if ($$mn eq "");
  $$mn="0$$mn"    if (length($$mn)==1);
  return 1        if (! &IsInt($$mn,0,59));

  # Check seconds
  $$s="00"        if ($$s eq "");
  $$s="0$$s"      if (length($$s)==1);
  return 1        if (! &IsInt($$s,0,59));

  return 0;
}

# $flag=&Date_DateCheck(\$y,\$m,\$d,\$h,\$mn,\$s,\$ampm,\$wk);
#   Returns 1 if any of the fields are bad.  All fields are optional, and
#   all possible checks are done on the data.  If a field is not passed in,
#   it is set to default values.  If data is missing, appropriate defaults
#   are supplied.
#
sub Date_DateCheck {
  my($y,$m,$d,$h,$mn,$s,$ampm,$wk)=@_;
  my($tmp1,$tmp2,$tmp3)=();

  my(@d_in_m)=(0,31,28,31,30,31,30,31,31,30,31,30,31);
  my($curr_y)=$Curr{"Y"};
  my($curr_m)=$Curr{"M"};
  my($curr_d)=$Curr{"D"};
  $$m=1, $$d=1  if (defined $$y and ! defined $$m and ! defined $$d);
  $$y=""     if (! defined $$y);
  $$m=""     if (! defined $$m);
  $$d=""     if (! defined $$d);
  $$wk=""    if (! defined $$wk);
  $$d=$curr_d  if ($$y eq "" and $$m eq "" and $$d eq "");

  # Check year.
  $$y=$curr_y             if ($$y eq "");
  $$y=&Date_FixYear($$y)  if (length($$y)<4);
  return 1                if (! &IsInt($$y,0,9999));
  $d_in_m[2]=29           if (&Date_LeapYear($$y));

  # Check month
  $$m=$curr_m             if ($$m eq "");
  $$m=$Lang{"MonthH"}{lc($$m)}
    if (exists $Lang{"MonthH"}{lc($$m)});
  $$m="0$$m"              if (length($$m)==1);
  return 1                if (! &IsInt($$m,1,12));

  # Check day
  $$d="01"                if ($$d eq "");
  $$d="0$$d"              if (length($$d)==1);
  return 1                if (! &IsInt($$d,1,$d_in_m[$$m]));
  if ($$wk) {
    $tmp1=&Date_DayOfWeek($$m,$$d,$$y);
    $tmp2=$Lang{"WeekH"}{lc($$wk)}
      if (exists $Lang{"WeekH"}{lc($$wk)});
    return 1      if ($tmp1 != $tmp2);
  }

  return &Date_TimeCheck($h,$mn,$s,$ampm);
}

# Takes a year in 2 digit form and returns it in 4 digit form
sub Date_FixYear {
  my($y)=@_;
  my($curr_y)=$Curr{"Y"};
  $y=$curr_y  if (! defined $y  or  ! $y);
  return $y  if (length($y)==4);
  confess "ERROR: Invalid year ($y)\n"  if (length($y)!=2);
  my($y1,$y2)=();

  if (lc($Cnf{"YYtoYYYY"}) eq "c") {
    $y1=substring($y,0,2);
    $y="$y1$y";

  } elsif ($Cnf{"YYtoYYYY"} =~ /^c(\d{2})$/i) {
    $y1=$1;
    $y="$y1$y";

  } elsif ($Cnf{"YYtoYYYY"} =~ /^c(\d{2})(\d{2})$/i) {
    $y1="$1$2";
    $y ="$1$y";
    $y += 100  if ($y<$y1);

  } else {
    $y1=$curr_y-$Cnf{"YYtoYYYY"};
    $y2=$y1+99;
    $y="19$y";
    while ($y<$y1) {
      $y+=100;
    }
    while ($y>$y2) {
      $y-=100;
    }
  }
  $y;
}

# &Date_NthWeekOfYear($y,$n);
#   Returns a list of (YYYY,MM,DD) for the 1st day of the Nth week of the
#   year.
# &Date_NthWeekOfYear($y,$n,$dow,$flag);
#   Returns a list of (YYYY,MM,DD) for the Nth DoW of the year.  If flag
#   is nil, the first DoW of the year may actually be in the previous
#   year (since the 1st week may include days from the previous year).
#   If flag is non-nil, the 1st DoW of the year refers to the 1st one
#   actually in the year
sub Date_NthWeekOfYear {
  my($y,$n,$dow,$flag)=@_;
  my($m,$d,$tmp,$date,%dow)=();
  $y=$Curr{"Y"}  if (! defined $y  or  ! $y);
  $n=1       if (! defined $n  or  $n eq "");
  return ()  if ($n<0  ||  $n>53);
  if (defined $dow) {
    $dow=lc($dow);
    %dow=%{ $Lang{"WeekH"} };
    $dow=$dow{$dow}  if (exists $dow{$dow});
    return ()  if ($dow<1 || $dow>7);
    $flag=""   if (! defined $flag);
  } else {
    $dow="";
    $flag="";
  }

  $y=&Date_FixYear($y)  if (length($y)<4);
  if ($Cnf{"Jan1Week1"}) {
    $date=&Date_Join($y,1,1,0,0,0);
  } else {
    $date=&Date_Join($y,1,4,0,0,0);
  }
  $date=&Date_GetPrev($date,$Cnf{"FirstDay"},1);
  $date=&Date_GetNext($date,$dow,1)  if ($dow ne "");

  if ($flag) {
    ($tmp)=&Date_Split($date);
    $n++  if ($tmp != $y);
  }

  if ($n>1) {
    $date=&DateCalc_DateDelta($date,"+0:0:". ($n-1) . ":0:0:0:0");
  } elsif ($n==0) {
    $date=&DateCalc_DateDelta($date,"-0:0:1:0:0:0:0");
  }
  ($y,$m,$d)=&Date_Split($date);
  ($y,$m,$d);
}

########################################################################
# LANGUAGE INITIALIZATION
########################################################################

# $hashref = &Date_Init_LANGUAGE;
#   This returns a hash containing all of the initialization for a
#   specific language.  The hash elements are:
#
#   @ month_name      full month names          January February ...
#   @ month_abb       month abbreviations       Jan Feb ...
#   @ day_name        day names                 Monday Tuesday ...
#   @ day_abb         day abbreviations         Mon Tue ...
#   @ day_char        day character abbrevs     M T ...
#   @ am              AM notations
#   @ pm              PM notations
#
#   @ num_suff        number with suffix        1st 2nd ...
#   @ num_word        numbers spelled out       first second ...
#
#   $ now             words which mean now      now today ...
#   $ last            words which mean last     last final ...
#   $ each            words which mean each     each every ...
#   $ of              of (as in a member of)    in of ...
#                     ex.  4th day OF June
#   $ at              at 4:00                   at
#   $ on              on Sunday                 on
#   $ future          in the future             in
#   $ past            in the past               ago
#   $ next            next item                 next
#   $ prev            previous item             last previous
#   $ later           2 hours later
#
#   % offset          a hash of special dates   { tomorrow->0:0:0:1:0:0:0 }
#   % times           a hash of times           { noon->12:00:00 ... }
#
#   $ years           words for year            y yr year ...
#   $ months          words for month
#   $ weeks           words for week
#   $ days            words for day
#   $ hours           words for hour
#   $ minutes         words for minute
#   $ seconds         words for second
#   % replace
#       The replace element is quite important, but a bit tricky.  In
#       English (and probably other languages), one of the abbreviations
#       for the word month that would be nice is "m".  The problem is that
#       "m" matches the "m" in "minute" which causes the string to be
#       improperly matched in some cases.  Hence, the list of abbreviations
#       for month is given as:
#         "mon month months"
#       In order to allow you to enter "m", replacements can be done.
#       $replace is a list of pairs of words which are matched and replaced
#       AS ENTIRE WORDS.  Having $replace equal to "m"->"month" means that
#       the entire word "m" will be replaced with "month".  This allows the
#       desired abbreviation to be used.  Make sure that replace contains
#       an even number of words (i.e. all must be pairs).  Any time a
#       desired abbreviation matches the start of any other, it has to go
#       here.
#
#   r sephm           hour/minute separator     (?::)
#   r sepms           minute/second separator   (?::)
#   r sepss           second/fraction separator (?:[.:])
#
#   Elements marked with an asterix (@) are returned as a set of lists.
#   Each list contains the strings for each element.  The first set is used
#   when the 7-bit ASCII (US) character set is wanted.  The 2nd set is used
#   when an international character set is available.  Both of the 1st two
#   sets should be complete (but the 2nd list can be left empty to force the
#   first set to be used always).  The 3rd set and later can be partial sets
#   if desired.
#
#   Elements marked with a dollar ($) are returned as a simple list of words.
#
#   Elements marked with a percent (%) are returned as a hash list.
#
#   Elements marked with (r) are regular expression elements which must not
#   create a back reference.
#
# ***NOTE*** Every hash element (unless otherwise noted) MUST be defined in
# every language.

sub Date_Init_English {
  my($d)=@_;

  $$d{"month_name"}=
    [["January","February","March","April","May","June",
      "July","August","September","October","November","December"]];

  $$d{"month_abb"}=
    [["Jan","Feb","Mar","Apr","May","Jun",
      "Jul","Aug","Sep","Oct","Nov","Dec"],
     [],
     ["","","","","","","","","Sept"]];

  $$d{"day_name"}=
    [["Monday","Tuesday","Wednesday","Thursday","Friday","Saturday","Sunday"]];
  $$d{"day_abb"}=
    [["Mon","Tue","Wed","Thu","Fri","Sat","Sun"]];
  $$d{"day_char"}=
    [["M","Tu","W","Th","F","Sa","Su"]];

  $$d{"num_suff"}=
    [["1st","2nd","3rd","4th","5th","6th","7th","8th","9th","10th",
      "11th","12th","13th","14th","15th","16th","17th","18th","19th","20th",
      "21st","22nd","23rd","24th","25th","26th","27th","28th","29th","30th",
      "31st"]];
  $$d{"num_word"}=
    [["first","second","third","fourth","fifth","sixth","seventh","eighth",
      "ninth","tenth","eleventh","twelfth","thirteenth","fourteenth",
      "fifteenth","sixteenth","seventeenth","eighteenth","nineteenth",
      "twentieth","twenty-first","twenty-second","twenty-third",
      "twenty-fourth","twenty-fifth","twenty-sixth","twenty-seventh",
      "twenty-eighth","twenty-ninth","thirtieth","thirty-first"]];

  $$d{"now"}     =["today","now"];
  $$d{"last"}    =["last","final"];
  $$d{"each"}    =["each","every"];
  $$d{"of"}      =["in","of"];
  $$d{"at"}      =["at"];
  $$d{"on"}      =["on"];
  $$d{"future"}  =["in"];
  $$d{"past"}    =["ago"];
  $$d{"next"}    =["next"];
  $$d{"prev"}    =["previous","last"];
  $$d{"later"}   =["later"];

  $$d{"offset"}  =["yesterday","-0:0:0:1:0:0:0","tomorrow","+0:0:0:1:0:0:0"];
  $$d{"times"}   =["noon","12:00:00","midnight","00:00:00"];

  $$d{"years"}   =["y","yr","year","yrs","years"];
  $$d{"months"}  =["mon","month","months"];
  $$d{"weeks"}   =["w","wk","wks","week","weeks"];
  $$d{"days"}    =["d","day","days"];
  $$d{"hours"}   =["h","hr","hrs","hour","hours"];
  $$d{"minutes"} =["mn","min","minute","minutes"];
  $$d{"seconds"} =["s","sec","second","seconds"];
  $$d{"replace"} =["m","month"];

  $$d{"sephm"}   =':';
  $$d{"sepms"}   =':';
  $$d{"sepss"}   ='[.:]';

  $$d{"am"}      = ["AM","A.M."];
  $$d{"pm"}      = ["PM","P.M."];
}

########################################################################
# FROM MY PERSONAL LIBRARIES
########################################################################

no integer;

# &ModuloAddition($N,$add,\$val,\$rem);
#   This calculates $val=$val+$add and forces $val to be in a certain range.
#   This is useful for adding numbers for which only a certain range is
#   allowed (for example, minutes can be between 0 and 59 or months can be
#   between 1 and 12).  The absolute value of $N determines the range and
#   the sign of $N determines whether the range is 0 to N-1 (if N>0) or
#   1 to N (N<0).  The remainder (as modulo N) is added to $rem.
#   Example:
#     To add 2 hours together (with the excess returned in days) use:
#       &ModuloAddition(60,$s1,\$s,\$day);
sub ModuloAddition {
  my($N,$add,$val,$rem)=@_;
  return  if ($N==0);
  $$val+=$add;
  if ($N<0) {
    # 1 to N
    $N = -$N;
    if ($$val>$N) {
      $$rem+= int(($$val-1)/$N);
      $$val = ($$val-1)%$N +1;
    } elsif ($$val<1) {
      $$rem-= int(-$$val/$N)+1;
      $$val = $N-(-$$val % $N);
    }

  } else {
    # 0 to N-1
    if ($$val>($N-1)) {
      $$rem+= int($$val/$N);
      $$val = $$val%$N;
    } elsif ($$val<0) {
      $$rem-= int(-($$val+1)/$N)+1;
      $$val = ($N-1)-(-($$val+1)%$N);
    }
  }
}

# $Flag=&IsInt($String [,$low, $high]);
#    Returns 1 if $String is a valid integer, 0 otherwise.  If $low is
#    entered, $String must be >= $low.  If $high is entered, $String must
#    be <= $high.  It is valid to check only one of the bounds.
sub IsInt {
  my($N,$low,$high)=@_;
  return 0  if (! defined $N  or
                $N !~ /^\s*[-+]?\d+\s*$/  or
                defined $low   &&  $N<$low  or
                defined $high  &&  $N>$high);
  return 1;
}


###
1;
