use GD;

my $w = 1366;
my $h = 168;
 
# create a new image
$im = GD::Image->new($w, $h);
 
# allocate some colors
$white = $im->colorAllocate(255,255,255);
$black = $im->colorAllocate(0,0,0);       
$red = $im->colorAllocate(255,0,0);      
$blue = $im->colorAllocate(0,0,255);
 
# make the background transparent and interlaced
$im->interlaced('true');

my $t1 = $w/52;
for(my $i = 0; $i < 52; $i++) {
	$im->rectangle($i * $t1, 0, ($i+1)*$t1, $h, $black);
}

# draw black keys.
my $t2 = $t1 * 0.6667;
$im->filledRectangle($t1 * 0.667, 0, $t1 * 0.667 * 2, $h * 0.6, $black);


my $start = $t1 * 2;

my @black = ( 0, 1, 3, 4, 5 );
for(my $i =0; $i < 7; $i++) {
	foreach(@black) {
		my $offset = 2 + $i * 7 + $_;
		$im->filledRectangle( ($offset + 0.667) * $t1, 0, ($offset + 0.667 * 2) * $t1, $h * 0.6, $black);
	}
}

open my $fh, ">",  "./piano.png" or die $!;
binmode $fh;
print $fh $im->png;
close $fh;
