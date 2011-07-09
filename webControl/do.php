<?php
require_once('commands.php');

$cmds = new Commands( $_GET['xml'] );
$cmds->runCommandId( $_GET['id'] );
?>
