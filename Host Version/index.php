<?php

if ((isset($_SERVER['HTTP_USER_AGENT']) and empty($_SERVER['HTTP_USER_AGENT'])) or !isset($_SERVER['HTTP_USER_AGENT'])){
    http_response_code(403);
   exit("<h2>Access Denied</h2></br>You don't have permission to view this site.</br>Error code:403 forbidden");
}
$isTextHTML=str_contains(($_SERVER['HTTP_ACCEPT']??''),'text/html');

const BASE_URL='https://panel:8443';  // example : https://cdn.domain.com

$URL=BASE_URL.$_SERVER['SCRIPT_URL']??'';

$ch = curl_init();

curl_setopt($ch,CURLOPT_URL,$URL);
curl_setopt($ch,CURLOPT_RETURNTRANSFER,true);
curl_setopt($ch, CURLOPT_HEADER, true);
curl_setopt($ch, CURLOPT_TIMEOUT, 10);
curl_setopt($ch, CURLOPT_USERAGENT, $_SERVER['HTTP_USER_AGENT']);
curl_setopt($ch,CURLOPT_CUSTOMREQUEST , 'GET');
curl_setopt($ch, CURLOPT_SSL_VERIFYHOST, false);
curl_setopt($ch, CURLOPT_SSL_VERIFYPEER, false);
curl_setopt($ch, CURLOPT_HTTPHEADER,$isTextHTML?[
    'Accept: text/html'
]:[]);

$data = curl_exec($ch);
$code = curl_getinfo($ch, CURLINFO_HTTP_CODE);
if (curl_error($ch)) {
    http_response_code($code);
    die('Error !');
}
curl_close($ch);
$headers=get_headers_from_curl_response($data);

if (!$isTextHTML and (empty($headers) or $code!==200) ){
http_response_code($code);
die('Error !');
}



foreach ($headers as $key=>$header){
    header("$key: $header");
}

function get_headers_from_curl_response(&$response): array
{
    $headers = [];

    $header_text = substr($response, 0, strpos($response, "\r\n\r\n"));

    foreach (explode("\r\n", $header_text) as $i=>$line) {
        if ( $i===0 ) continue;
        list ($key, $value) = explode(': ', $line);

        if (in_array($key,['content-disposition','content-type','subscription-userinfo','profile-update-interval'])) $headers[$key] = $value;
    }
    $response=trim(str_replace($header_text,'',$response));
    return $headers;
}

echo $data;