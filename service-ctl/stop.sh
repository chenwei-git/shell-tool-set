#!/bin/bash 

function is_alive() {
app_name=$1
echo "is_alive: ${app_name} is alive?"
app_pid_count=$(ps -ef | grep "${app_name}" | grep -v "grep\|$$" | wc -l)

if (( $app_pid_count > 0 ))
then 
  app_pid=$(ps -ef | grep "${app_name}" | grep -v "grep\|$$" | awk '{print $2}')
  echo "is_alive: ${app_name} is alive, app_pid = ${app_pid}"
  return 1
else
  echo "is_alive: ${app_name} is dead"
  return 0
fi
}

function is_expectable() {
app_name=$1
watch_time=$2
expect_result=$3
while :
do
  is_alive $app_name
  if (( $? == $expect_result ))
  then
    return 1
  fi
  if (( $watch_time < 0 ))
  then
    return 0
  fi
  watch_time=$(( watch_time-1 ))
  sleep 1s
done
}

function stop_on_alive() {
app_name=$1
echo "stop_on_alive: ${app_name} to be stop..."
while :
do
  rt=`curl -s -X POST "http://localhost:9011/glp-hello/manage/shutdown" -H "Content-type: application/json"`
  if [[ -z $rt ]]
  then
    echo "stop_on_alive: stop ${app_name} success"
    break
  else
    echo "stop_on_alive: $rt"
    sleep 1s
  fi
done
}

function start_on_dead() {
app_name=$1
echo "start_on_dead: $app_name to be start..."
app_path="/user/appuser01/app-core/glp-hello/"$app_name
`nohup java -server -XX:+UseG1GC -Xmx256m -XX:MaxGCPauseMillis=1000 -jar $app_path --spring.profiles.active=test-peer2 >/dev/null 2>&1 &`
echo "start_on_dead: start ${app_name} success"
}

function stop() {
app_name=$1
echo "stop: ${app_name} to be stop..."
is_alive $app_name
if (( $? != 0 ))
then
  stop_on_alive $app_name
  is_expectable $app_name 60 0
  if (( $? == 0 ))
  then 
    echo "stop: stop ${app_name} fail"
    return 0
  else
    echo "stop: stop ${app_name} success"
    return 1
  fi
else
  echo "stop: ${app_name} is already dead"
  return 1
fi
}

function start() {
app_name=$1
echo "start: ${app_name} to be start..."
is_alive $app_name
if (( $? == 0 ))
then
  start_on_dead $app_name
  is_expectable $app_name 60 1
  if (( $? == 0 ))
  then 
    echo "start: start ${app_name} fail"
    return 0
  else
    echo "start: start ${app_name} success"
    return 1
  fi
else
  echo "start: $app_name is alrealy alive"
  return 1
fi
}

echo "main: begin..."
if (( $# == 1 ))
then
  to_stop_app=$1
else
  echo "main: input params error, please input one param, first is to_stop_app"
  exit 1
fi

stop $to_stop_app
if (( $? == 0 ))
then
  echo "main: stop ${to_stop_app} fail"
  exit 2
else
  echo "main: stop ${to_stop_app} success"
fi

echo "main: end"
