from docker import AutoVersionClient
import os
import sys
# python 3.x
# import http.client
# python 2.x
import httplib


PORT = os.getenv('PORT')
JOB_NAME = os.getenv('JOB_NAME')
DOCKER_ADDRESS = os.getenv('DOCKER_ADDRESS')
REGISTRY_ADDRESS = os.getenv('REGISTRY_ADDRESS')
WORKSPACE = os.getenv('WORKSPACE')

DOCKERFILE = WORKSPACE + '/Dockerfile'
IMAGE_NAME = JOB_NAME
FULL_IMAGE_NAME=REGISTRY_ADDRESS + '/' + IMAGE_NAME

# http://docker-py.readthedocs.org/en/latest/api/#containers
jenkinsCli = AutoVersionClient(base_url='localhost:2375',timeout=10)
swarmCli = AutoVersionClient(base_url=DOCKER_ADDRESS,timeout=10)
# registryConn = http.client.HTTPConnection(REGISTRY_ADDRESS)
registryConn = httplib.HTTPConnection(REGISTRY_ADDRESS)

def remove_image_in_registry():
    try:
        registryConn.request('GET','v1/repositories/' + IMAGE_NAME + '/tags/latest')
        response = registryConn.getresponse()
        print("query image %s in registry,http status %d" %(FULL_IMAGE_NAME,response.status))
        # if image is in registry
        if response.status / 100 == 2 :
            print("registry image %s id : %s" %(FULL_IMAGE_NAME,response.read()))
            registryConn.request('DELETE','v1/repositories/'+ IMAGE_NAME + '/tags/latest')
            r = registryConn.getresponse()
            print("delete image %s in registry,http status %d" %(FULL_IMAGE_NAME,r.status))
        else :
            print("query image %s in registry fail,resason %s" %(FULL_IMAGE_NAME,response.reason))
    except Exception as inst:
        print(type(inst))    # the exception instance
        print(inst.args)     # arguments stored in .args
        print(inst)          # __str__ allows args to be printed directly
        pass
    finally:
      	registryConn.close()

def remove_container_with_imageName():
    response = swarmCli.containers(all=True)
    container_num = len(response)
    if container_num > 0 :
        i=0
        while i < container_num :  
             if response[i]['Image'] == FULL_IMAGE_NAME :
                 print('remove container :' + response[i]['Names'][0])
                 print('remove container id :' + response[i]['Id'])
                 swarmCli.remove_container(response[i]['Id'],force=True)
             i=i+1

def clear():
    # delete image in jenkins
    try:
        print("remove image : %s in jenkins" %(FULL_IMAGE_NAME))
        jenkinsCli.remove_image(FULL_IMAGE_NAME,force=True,noprune=False)
    except Exception as inst:
        print(type(inst))    # the exception instance
        print(inst.args)     # arguments stored in .args
        print(inst)          # __str__ allows args to be printed directly
        pass
    # remove image in registry
    remove_image_in_registry()
    # remove container in swarm
    remove_container_with_imageName()
    # remove image in swarm
    try:
        print("remove image : %s in swarm" %(FULL_IMAGE_NAME))
        swarmCli.remove_image(FULL_IMAGE_NAME,force=True,noprune=False)
    except Exception as inst:
        print(type(inst))    # the exception instance
        print(inst.args)     # arguments stored in .args
        print(inst)          # __str__ allows args to be printed directly
        pass
      
def build():
    # remove dockerfile
    if(os.path.isfile(DOCKERFILE)):
        os.remove(DOCKERFILE)
    file = open(DOCKERFILE,mode='a+')
    file.write("FROM %s \n"%(REGISTRY_ADDRESS + '/tomcat7'))
    file.write('ADD target/*.war $TOMCAT_HOME/webapps/ \n')
    file.write('CMD  bash start.sh')
    file.close()
    print('build dockerfile')
    response = [line for line in jenkinsCli.build(path=WORKSPACE, rm=True, tag=FULL_IMAGE_NAME)]
    response

def push():
    print("push image : %s from jenkins to registry" %(FULL_IMAGE_NAME))
    response = [line for line in jenkinsCli.push(FULL_IMAGE_NAME, stream=True)]
    response

def run():
    # pull image
    for line in swarmCli.pull(FULL_IMAGE_NAME, stream=True):
        print(line)
    # create container
    config = swarmCli.create_host_config(binds=['/logs:/logs'],port_bindings={8080:PORT,8000:None},publish_all_ports=True)
    container = swarmCli.create_container(image=FULL_IMAGE_NAME,name=IMAGE_NAME,ports=[8080,8000],volumes=['/logs'],host_config=config)
    print(container)
    # start container
    response = swarmCli.start(container=container.get('Id'))
    print(response)
def main():
  try:
      clear()
      # build dockerfile
      build()
      # push image from jenkins to registry
      push()
      # pull image,create container,start container
      run()
      sys.exit(0)
  except Exception as inst:
      print(type(inst))    # the exception instance
      print(inst.args)     # arguments stored in .args
      print(inst)          # __str__ allows args to be printed directly
      sys.exit(1)
  finally:
      jenkinsCli.close()
      swarmCli.close()
main()