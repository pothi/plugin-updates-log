<?php
function getData($url) {
    if(is_callable('curl_init')){
      $ch = curl_init();
      $timeout = 5;
      curl_setopt($ch, CURLOPT_URL, $url);
      curl_setopt($ch, CURLOPT_RETURNTRANSFER, 1);
      curl_setopt($ch, CURLOPT_CONNECTTIMEOUT, $timeout);
      $data = curl_exec($ch);
      curl_close($ch);
      return $data;
    }else{
        return file_get_contents($url);
    }
}

//check for latest WordPress version
$apiUrl = 'http://api.wordpress.org/core/version-check/1.6/';
$apiFile = 'cache/api.json';

if((is_file($apiFile) and filemtime($apiFile)< time()-3600) OR !is_file($apiFile))
{
  $apiContent = getData($apiUrl);
  if($apiContent!=''){
    file_put_contents($apiFile, $apiContent);
  }
}

$apiContent = file_get_contents($apiFile);
$apiReturn = unserialize($apiContent);
$current_version = $apiReturn['offers'][0]['current'];

// var_dump( $apiReturn );

// echo 'Current WordPress version is ' . $current_version . '!' . PHP_EOL;
echo $current_version . PHP_EOL;
