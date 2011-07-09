<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Strict//EN"
  "http://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd">
<html xmlns="http://www.w3.org/1999/xhtml"><head>
<title>RX-V2400 Controller</title>
<meta name="viewport"
  content="width=320; initial-scale=1.0; maximum-scale=1.0; user-scalable=no;"/>
<style type="text/css" media="screen">@import "iui/iui/iui.css";</style>
<script type="application/x-javascript" src="iui/iui/iui.js"></script>
<script type="application/x-javascript" src="controls.js"></script>
<script type="application/x-javascript" src="ajax.js"></script>
<?php
require_once('commands.php');
$cmds = new Commands('commands.xml');
$musiccmds = new Commands('music.xml');
?>
<script type="application/x-javascript">
<?php foreach (range(1,3,1) as $zone) {?>
function setZone<?php echo($zone);?>Volume(event)
{
    var value = event.target.options[event.target.selectedIndex].value;
    if ( value == 'Mute' )
    {
        iui.showPageByHref('do.php?xml=commands.xml&id=<?php echo($cmds->commandTitleToId("Zone $zone Mute On"));?>',null,'GET',null,null);
    } else {
        iui.showPageByHref('do.php?xml=commands.xml&id=<?php echo($cmds->commandTitleToId("Zone $zone Mute Off"));?>',null,'GET',null,null);
        switch(parseInt(value))
        {
            <?php
                foreach (range(-45, -15, 0.5) as $number) {
                    $number = number_format($number,1,'.','');
                    echo "case $number:\n";
                    ?>iui.showPageByHref('do.php?xml=commands.xml&id=<?php echo($cmds->commandTitleToId("Control System Zone $zone Volume Set $number"));?>',null,'GET',null,null);<?php
                    echo "\nbreak;\n";
                } ?>
            default:
                alert(value);
        }
    }
    ajaxpoll();
}
<?php }?>
</script>
<link rel="apple-touch-icon" href="RX-V2400.tiff"/>
</head>
<body>
<div class="toolbar">
  <h1 id="pageTitle"></h1>
  <a id="backButton" class="button" href="#"></a>
</div>
    <form id="settings" title="Controller" class="panel" selected="true">
        <h2>Control</h2>
        <fieldset>
            <div class="row">
                <label>System Power</label>
                <div class="toggle" onclick="toggle(event,<?php echo($cmds->commandTitleToId('Power On'));?>,<?php echo($cmds->commandTitleToId('Power Off'));?>);" id="systemPower"><span class="thumb"></span><span class="toggleOn">ON</span><span class="toggleOff">OFF</span></div>
            </div>
            <div class="row" id="z1menuSelect">
                <a href="#zone1control">Zone One<label class="status" id="z1menuStatus">On</label></a>
            </div>
            <div class="row" id="z2menuSelect">
                <a href="#zone2control">Zone Two<label class="status" id="z2menuStatus">On</label></a>
            </div>
            <div class="row" id="z3menuSelect">
                <a href="#zone3control">Zone Three<label class="status" id="z3menuStatus">Off</label></a>
            </div>
        </fieldset>

        <h2>Features</h2>
        <fieldset>

            <div class="row">
                <a href="schedule.php">Schedule</a>
            </div>
            <div class="row">
                <a href="status.php">Status</a>
            </div>
            <div class="row">
                <a href="#music">Music</a>
            </div>
            <div class="row">
                <a href="#macros">Macros</a>
            </div>
            <div class="row">
                <a href="#classic">Classic Mode</a>
            </div>
        </fieldset>
    </form>

    <?php foreach (range(1,3,1) as $zone) {?>
    <form id="zone<?php echo($zone);?>control" title="Controller" class="panel">
        <h2>Zone <?php echo($zone);?></h2>
        <fieldset>
            <div class="row">
                <label>Power</label>
                <div class="toggle" onclick="toggle(event,<?php echo($cmds->commandTitleToId("Zone $zone Power On"));?>,<?php echo($cmds->commandTitleToId("Zone $zone Power Off"));?>);" id="Zone<?php echo($zone);?>Power"><span class="thumb"></span><span class="toggleOn">ON</span><span class="toggleOff">OFF</span></div>
            </div>
            <div class="row">
                <label>Volume</label>
                <select name="role" id="Zone<?php echo($zone);?>Volume" onchange="setZone<?php echo($zone);?>Volume(event,<?php echo($zone);?>);">
                    <option value='Mute'>Mute</option>
                    <?php
                        foreach (range(-45, -15, 0.5) as $number) {
                            $number = number_format($number,1,'.','');
                            echo "<option value='$number'>$number dB</option>";
                        } ?>
                </select>
            </div>
        </fieldset>

        <h2>Input</h2>
        <fieldset>
            <div class="row">
                <a href="do.php?xml=commands.xml&id=<?php echo($cmds->commandTitleToId("Zone $zone Input DVD"));?>">DVD</a>
            </div>
            <div class="row">
                <a href="do.php?xml=commands.xml&id=<?php echo($cmds->commandTitleToId("Zone $zone Input TUNER"));?>">Tuner</a>
            </div>
            <div class="row">
                <a href="do.php?xml=commands.xml&id=<?php echo($cmds->commandTitleToId("Zone $zone Input Bluetooth"));?>">Bluetooth</a>
            </div>
        </fieldset>
    </form>
    <?php }?>


    <form id="music" title="Music" class="panel">
        <fieldset>
<?php
$id = 0;
foreach( $musiccmds->getCommands() as $cmd ) {
  if ( 'header' == $musiccmds->getCommandClass($id) )
  {
    echo("</fieldset><h2>$cmd</h2><fieldset>");
  } else { ?>
    <div class="row">
      <a href="do.php?xml=music.xml&id=<?php echo($id);?>"><?php echo( $cmd ); ?></a>
    </div><?php
  }
  $id++; } ?>
        </fieldset>
    </form>

<ul title="Commands" id="classic">
<li>
<select name="role" id="popup">
                        <option value="Judge">Judge</option>
                        <option value="Admin">Admin</option>
                </select>
</li>
<li>
            <div class="row">
                <label>Repeat</label>
                <div class="toggle" onclick=""><span class="thumb"></span><span class="toggleOn">ON</span><span class="toggleOff">OFF</span></div>
            </div>
</li>
<?php
$id = 0;
foreach( $cmds->getCommands() as $cmd ) {
?>
<li>
<a href="do.php?xml=commands.xml&id=<?php echo($id);?>"><?php echo( $cmd ); ?></a>
</li>
<?php $id++; } ?>
</ul>
</body></html>
