<html><body>
<?php
require_once('commands.php');
$cmds = new Commands();
?>
<?php
$id = 0;
foreach( $cmds->getCommands() as $cmd ) {
?>
<a href="do.php?id=<?php echo($id);?>"><?php echo( $cmd ); ?></a><br/>
<?php $id++; } ?>
</body></html>
