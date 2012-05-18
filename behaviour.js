print "Content-Type: text/javascript\n\n";

print <<'EOF';
function getElementsByClassName(node,classname) {
  if (node.getElementsByClassName) { // use native implementation if available
    return node.getElementsByClassName(classname);
  } else {
    return (function getElementsByClass(searchClass,node) {
        if ( node == null )
          node = document;
        var classElements = [],
            els = node.getElementsByTagName("*"),
            elsLen = els.length,
            pattern = new RegExp("(^|\\s)"+searchClass+"(\\s|$)"), i, j;

        for (i = 0, j = 0; i < elsLen; i++) {
          if ( pattern.test(els[i].className) ) {
              classElements[j] = els[i];
              j++;
          }
        }
        return classElements;
    })(classname, node);
  }
}

function toggle(x) {
   var elements = getElementsByClassName(document, x),
       n = elements.length;
   for (var i = 0; i < n; i++) {
     var e = elements[i];

     if(e.style.display == 'block') {
       e.style.display = 'none';
     } else {
       e.style.display = 'block';
     }
  }
}
EOF
