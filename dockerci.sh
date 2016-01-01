#!/bin/sh
set +e

SWARM_ADDRESS=192.168.3.56:2375
echo "$SWARM_ADDRESS =======================================================================================================================temp use"
REGISTRY_ADDRESS=192.168.3.56:5000
IMAGE_NAME=$JOB_NAME
WORK_DIR=/usr/local/tomcat/webapps/hudson/jobs/$JOB_NAME/workspace

# 清除jenkins本地docker image
echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>> remove local $REGISTRY_ADDRESS/$IMAGE_NAME"
IMAGEID=$(docker images | grep "$IMAGE_NAME" | awk '{print $3}')
echo $IMAGEID
if [[ "$IMAGEID"x != ""x ]];then
  /usr/bin/docker rmi $IMAGEID
fi


# 清除workspace dockerfile
if [ -f $WORK_DIR/Dockerfile ]; then
  rm $WORK_DIR/Dockerfile
fi

echo "FROM $REGISTRY_ADDRESS/tomcat7" >> $WORK_DIR/Dockerfile
echo 'ADD target/*.war $TOMCAT_HOME/webapps/' >> $WORK_DIR/Dockerfile
echo 'CMD  bash start.sh' >> $WORK_DIR/Dockerfile

echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>> build docker image local"
/usr/bin/docker build -t $REGISTRY_ADDRESS/$IMAGE_NAME $WORK_DIR | tee $WORK_DIR/Docker_build_result.log

RESULT=$(cat "$WORK_DIR"/Docker_build_result.log | tail -n 1)
if [[ "$RESULT" != *Successfully* ]];then
  exit -1
fi

# 清除docker registry上的image以节省空间
echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>> delete docker image in registry"
RE1=$(curl -XGET http://"$REGISTRY_ADDRESS"/v1/repositories/"$IMAGE_NAME"/tags/latest)
if [[ "$RE1" != *error* ]];then
  RE2=$(curl -XDELETE http://"$REGISTRY_ADDRESS"/v1/repositories/"$IMAGE_NAME"/tags/latest)
  if [ ! "$RE2" ]; then
    echo "docker registry detele image failure"
    exit -1
  fi
fi

echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>> push local docker image to registry"
RE6=$(/usr/bin/docker push "$REGISTRY_ADDRESS/$IMAGE_NAME")
if [[ $RE6 == *Error* ]]; then
    echo $RE6
    exit -1
fi

echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>> remove container in docker swarm"
## 清除docker swarm的contaienr
containers=$(curl -XGET http://"$SWARM_ADDRESS"/v1.14/containers/json?all=1 | jq -r '.[] |.Image, .Id')
index=0
# next = 0 true   next = 1 false
next=1
for container in `echo $containers`
do
    # image name used by container
    if [ $((index%2)) -eq 0 ]; then
        if [[ "$container" == *$REGISTRY_ADDRESS/$IMAGE_NAME* ]]; then
            echo "matched image name ==> $container"
            next=0
        fi
    else
        # container id
        if [ $next -eq 0 ];then
            echo "matched container id ==> $container"
            curl -XDELETE http://$SWARM_ADDRESS/v1.14/containers/$container?force=1
            next=1
        fi
    fi
    # echo "current index ==> $index"
    let "index+=1"
done                     

## 清除docker swarm的image
echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>> remove image in docker swarm"
RE3=$(curl -XDELETE http://$SWARM_ADDRESS/v1.14/images/"$REGISTRY_ADDRESS/$IMAGE_NAME"?force=1)
echo $RE3
# if [[ $RE3 != *Deleted*  ]];then
#    exit -1
# fi

## 如果用户没有设置，表示手动部署
echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>> $DOCKER_ADDRESS"
echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>> $PORT"
if [[ "$DOCKER_ADDRESS"x == ""x ]] || [[ "$PORT"x == ""x  ]] ;then
    echo ">>> you need to deploy the project manually"
    exit 0
fi

echo ">>>>>>>>>>>>>>>>>>>>> deploy the $JOB_NAME automatically to $DOCKER_ADDRESS and expose the 8080 to $PORT"
## restful api 在run 容器前必须pull image create container 完事 start container

echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>  $DOCKER_ADDRESS pull image"
RE4=$(curl -XPOST http://"$DOCKER_ADDRESS"/v1.14/images/create?fromImage="$REGISTRY_ADDRESS/$IMAGE_NAME")
if [[ $RE4 == *error*  ]];then
    echo $RE4
    exit -1
fi

echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>  $DOCKER_ADDRESS create container"
CONTAINERID=$(curl -XPOST -H "Content-Type: application/json" --data "{
    \"Hostname\":\"\",
    \"Domainname\": \"\",
    \"User\":\"\",
    \"AttachStdin\":false,
    \"AttachStdout\":true,
    \"AttachStderr\":true,
    \"PortSpecs\":null,
    \"Tty\":false,
    \"OpenStdin\":false,
    \"StdinOnce\":false,
    \"WorkingDir\":\"\",
    \"NetworkDisabled\": false,
    \"RestartPolicy\": { \"Name\": \"always\" },
    \"ExposedPorts\": {
        \"8080/tcp\": {},
        \"8000/tcp\": {}
    },
    \"Image\":\"$REGISTRY_ADDRESS/$IMAGE_NAME\"
}"  http://"$DOCKER_ADDRESS"/v1.14/containers/create?name="$IMAGE_NAME" | jq -r .Id)

if [[ $CONTAINERID == *null*  ]] || [[ $CONTAINERID == *error* ]]; then
    echo $CONTAINERID
    exit -1
fi
# start container
echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>  $DOCKER_ADDRESS start container"
RE5=$(curl -XPOST -H "Content-Type: application/json" --data "{
    \"Binds\":[\"/logs:/logs\"],
    \"PortBindings\":{ \"8080/tcp\": [{ \"HostPort\": \"$PORT\" }] },
    \"PublishAllPorts\":true,
    \"Dns\": [\"$DOCKER_DNS_ADDRESS\"],
    \"Privileged\":false
}" http://"$DOCKER_ADDRESS"/v1.14/containers/"$CONTAINERID"/start)
echo $RE5
if [[ "$RE5"x != ""x ]]; then
    exit -1
fi
                                                    