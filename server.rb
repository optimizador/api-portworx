# server.rb
require 'sinatra'
require 'pg'
require "sinatra/namespace"
require 'rest-client'

set :bind, '0.0.0.0'
set :port, 8080


get '/' do
    'APIs Portworx'
end

namespace '/api/lvl2' do
  before do
    content_type 'application/json'
  end

  #urlapi="localhost:8080"
  urlapi="https://apis.9sxuen7c9q9.us-south.codeengine.appdomain.cloud"
  urlapi2 = "localhost:8080"

  get '/portworxsol' do #Asynchronous DR
    logger = Logger.new(STDOUT)
    resultado = []
    precio_final = 0
    ##########################
    # Calculo clúster 
    ##########################
    tipo_cluster = "#{params['tipo_cluster']}" #IKS o OCP
    wn = "#{params['wn']}"
    region_cluster = "#{params['region_cluster']}"
    infra_type = "#{params['infra_type']}"
    flavor = "#{params['flavor']}"

    cluster = {}

    if (tipo_cluster == 'ocp')
      logger.info("url: #{urlapi}/api/v1/preciocluster?region=#{region_cluster}&wn=#{wn}&flavor=#{flavor}&infra_type=#{infra_type}")
      respuesta_cluster = RestClient.get "#{urlapi}/api/v1/preciocluster?region=#{region_cluster}&wn=#{wn}&flavor=#{flavor}&infra_type=#{infra_type}", {:params => {}}
    end

    if (tipo_cluster == 'iks')
      logger.info("url: #{urlapi}/api/v1/ikspreciocluster?region=#{region_cluster}&wn=#{wn}&flavor=#{flavor}&infra_type=#{infra_type}")
      respuesta_cluster = RestClient.get "#{urlapi}/api/v1/ikspreciocluster?region=#{region_cluster}&wn=#{wn}&flavor=#{flavor}&infra_type=#{infra_type}", {:params => {}}
    end

    cluster=JSON.parse(respuesta_cluster.to_s)
    logger.info("RestClient: " +respuesta_cluster.to_s)
    logger.info("JSON: "+ cluster.to_s)
    precio_final=precio_final+cluster[0]["precio"]

    ##########################
    # Calculo Block Storage
    ##########################

    iops = "#{params['iops']}"
    region_storage = "#{params['region_storage']}"
    storage = "#{params['storage']}"
    
    block_storage = {}

    logger.info("url: #{urlapi}/api/v1/sizingblockstorage?region=#{region_storage}&iops=#{iops}&storage=#{storage}")
    respuestastorage = RestClient.get "#{urlapi}/api/v1/sizingblockstorage?region=#{region_storage}&iops=#{iops}&storage=#{storage}", {:params => {}}
    block_storage=JSON.parse(respuestastorage.to_s)
    logger.info("RestClient: " +respuestastorage.to_s);
    logger.info("JSON: "+ block_storage.to_s);
    precio_final=precio_final+block_storage[0]["preciounidadrestante"].to_f
    
    ##########################
    # Calculo DB for ETCD
    ##########################

    region_etcd = "#{params['region_etcd']}"
    ram_etcd = "#{params['ram_etcd']}"
    storage_etcd ="#{params['storage_etcd']}"
    cores_etcd = "#{params['cores_etcd']}"

    db_etcd = {}

    logger.info("url: #{urlapi2}/api/v1/dbforetcdprecio?region=#{region_etcd}&ram=#{ram_etcd}&storage=#{storage_etcd}&cores=#{cores_etcd}")
    respuesta_db_etcd = RestClient.get "#{urlapi2}/api/v1/dbforetcdprecio?region=#{region_etcd}&ram=#{ram_etcd}&storage=#{storage_etcd}&cores=#{cores_etcd}", {:params => {}}
    db_etcd = JSON.parse(respuesta_db_etcd.to_s)
    logger.info("RestClient: " + respuesta_db_etcd.to_s)
    logger.info("JSON: " + db_etcd.to_s)
    precio_final = precio_final + db_etcd[0]["precio"].to_f

    ##########################
    # Calculo Portworx
    ##########################

    region_portworx = "#{params['region_portworx']}"
    tipo_portworx = infra_type
    wn_portworx = wn

    portworx = {}

    logger.info("url: ")
    respuesta_portworx = RestClient.get "#{urlapi2}/api/v1/portworxprecio?region=#{region_portworx}&tipo=#{tipo_portworx}&workers=#{wn_portworx}"
    portworx = JSON.parse(respuesta_portworx.to_s)
    logger.info("RestClient: " + respuesta_portworx.to_s)
    logger.info("JSON: " + portworx.to_s)
    precio_final = precio_final + portworx[0]["precio"].to_f

    resultado.push(cluster: cluster[0], block_storage: block_storage[0], db_etcd:db_etcd[0], portworx:portworx[0], preciototal:precio_final.round(2))
    resultado.to_json
  end
end

namespace '/api/v1' do
  before do
    content_type 'application/json'
  end

####################################################################
#
# Servicios para dimensionamiento de Portworx
#
####################################################################

  get '/portworxprecio' do
    logger = Logger.new(STDOUT)
    region = "#{params['region']}"
    tipo="#{params['tipo']}"
    workers="#{params['workers']}"
    resultado=[]
    precio=0
    begin
      logger.info("calculando precio portworx")
      if tipo == 'baremetal'
        precio = workers.to_i*0.928*720
      end
      if tipo == 'shared' || tipo == 'dedicated'
        precio = workers.to_i*0.357*720
      end
      logger.info("precio: "+precio.round(2).to_s)
      resultado.push ({region: region, workers: workers, tipo: tipo, precio: precio.round(2).to_f})
    rescue PG::Error => e
      logger.info(e.message.to_s)
    end
    resultado.to_json
  end

####################################################################
#
# Servicios para dimensionamiento de DB for etcd
#
####################################################################

  get '/dbforetcdprecio' do
    logger = Logger.new(STDOUT)
    region = "#{params['region']}"
    ram = "#{params['ram']}"
    storage ="#{params['storage']}"
    cores = "#{params['cores']}"
    precio_ram = 17.25
    precio_storage = 2.001
    precio_cores = 103.5
    precio = 0
    resultado = []
    begin
      logger.info("calculando precio db for etcd")
      precio = (ram.to_i * precio_ram) + (storage.to_i * precio_storage) + (cores.to_i * precio_cores)
      logger.info("precio: "+precio.round(2).to_s)
      resultado.push({ region: region, ram: ram, storage: storage, cores: cores, precio: precio.round(2).to_f})
    rescue PG::Error => e
      logger.info(e.message.to_s)
    end
    resultado.to_json
  end
end
