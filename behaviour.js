print "Content-Type: text/javascript\n\n";

print <<'EOF';
function toggle(x) {
	if (document.getElementById(x).style.display == '') {
		document.getElementById(x).style.display = 'block';
	} else {
		document.getElementById(x).style.display = '';
	}
}


EOF
