<?php
require_once('commands.php');

$cmds = new Commands('commands.xml');
$output = $cmds->runCommand( "status\nbye\n" );

$output = preg_replace('/\n/','<br>',$output);
$output = preg_replace('/\s/','&nbsp;',$output);

echo '
<div id="do" title="Do" class="panel">
    ';
echo $output;
echo '
    <p>
</div>
';
?>
