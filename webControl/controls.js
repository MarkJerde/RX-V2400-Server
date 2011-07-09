
function findParent(node, localName)
{
	while (node && (node.nodeType != 1 || node.localName.toLowerCase() != localName))
		node = node.parentNode;
	return node;
}
function hasClass(self, name)
{
	var re = new RegExp('(^|\\s)'+name+'($|\\s)');
	return re.exec(self.getAttribute('class')) != null;
}
function toggle(event, onCmd, offCmd)
{
    var div = findParent(event.target, 'div');
    if (div && hasClass(div, 'toggle'))
    {
        if ( div.getAttribute('toggled') == 'true' )
        {
            iui.showPageByHref('do.php?xml=commands.xml&id=' + onCmd,null,'GET',null,null);
            //document.getElementById('z1menuSelect').style.display = 'inline';
            //document.getElementById('z2menuSelect').style.display = 'inline';
            //document.getElementById('z3menuSelect').style.display = 'inline';
        } else {
            iui.showPageByHref('do.php?xml=commands.xml&id=' + offCmd,null,'GET',null,null);
            //document.getElementById('z1menuSelect').style.display = 'none';
            //document.getElementById('z2menuSelect').style.display = 'none';
            //document.getElementById('z3menuSelect').style.display = 'none';
        }
		ajaxpoll();
    }
}
