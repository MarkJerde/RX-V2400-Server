<?php
class Commands
{
  private $_commands;

  function __construct( $file )
  {
    $this->_commands = array();

    $doc = new DOMDocument();
    $doc->load($file);
    $cmds = $doc->getElementsByTagName( 'command' );
    foreach( $cmds as $cmd )
    {
      $this->_commands []= array( 
        'title' => $cmd->getAttribute('title'),
        'class' => $cmd->getAttribute('class'),
        'command' => $cmd->firstChild->nodeValue
      );
    }
  }

  function getCommands()
  {
    $cmds = array();
    foreach( $this->_commands as $cmd )
    {
      $cmds []= $cmd['title'];
    }
    return $cmds;
  }

  function getCommandClass( $id )
  {
    return $this->_commands[$id]['class'];
  }

  function commandTitleToId( $title )
  {
    $id = 0;
    foreach( $this->getCommands() as $cmd )
    {
      if ( $cmd == $title )
      {
        return $id;
      }
      $id++;
    }
    return -1;
  }

  function runCommandId( $id )
  {
    $output = $this->runCommand($this->_commands[$id]['command']);
    return;

    $output = preg_replace('/.*type .help. for documentation.\n/s','',$output);
    $output = preg_replace('/Goodbye\.\s*/s','',$output);
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
  }

  function runCommand( $command )
  {
    $descriptorspec = array(
      0 => array("pipe", "r"), // stdin is a pipe that the child will read from
      1 => array("pipe", "w"), // stdout is a pipe that the child will write to
      2 => array("pipe", "w")); // stderr is a pipe that the child will write to

    $process = proc_open("telnet localhost 8675", $descriptorspec, $pipes);

    if (is_resource($process)) {
      // $pipes now looks like this:
      // 0 => writeable handle connected to child stdin
      // 1 => readable handle connected to child stdout
      // 2 => readable handle connected to child stderr

      fwrite($pipes[0], $command);
      while(($status = proc_get_status($process)) && $status["running"])
      {
        sleep(1);
      }

      fclose($pipes[0]);
      $output = stream_get_contents($pipes[1]);

      fclose($pipes[1]);
      fclose($pipes[2]);

      // It is important that you close any pipes before calling
      // proc_close in order to avoid a deadlock
      $return_value = proc_close($process);
//echo $return_value;

      $output = preg_replace('/.*type .help. for documentation.\n/s','',$output);
      $output = preg_replace('/Goodbye\.\s*/s','',$output);

      return $output;
    }
  }
}
?>
