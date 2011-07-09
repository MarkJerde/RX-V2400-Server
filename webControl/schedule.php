<?php
require_once('commands.php');

$cmds = new Commands('commands.xml');
$output = $cmds->runCommand( "schedule\nbye\n" );

$output = preg_replace('/(\n|^)(\d+)\./','</label></div></fieldset><h2>$2</h2><fieldset><div class="row"><label>',$output);
$output = preg_replace('/^<\/label><\/div><\/fieldset>/','',$output);
$output = preg_replace('/\s*$/s','',$output);
$output = preg_replace('/\n/','</label></div><div class="row"><label>',$output);
$output = preg_replace('/<div class="row">\s*<label><\/label><\/div>/','',$output);
//$output = preg_replace('/\s/','&nbsp;',$output);

echo '
<div id="schedule" title="Schedule" class="panel">
    ';
echo $output;
echo '</label>
        </div>
    </fieldset>
</div>
';
?>
