# server.rb
require 'sinatra'
require 'pg'
require "sinatra/namespace"
require 'rest-client'
require 'thin' 
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
  urlapi="http://apis.ioi17ary7au.svc.cluster.local"
  urlapi2 = "http://apis-portworx.ioi17ary7au.svc.cluster.local"

  get '/portworxsol' do #Asynchronous DR
    logger = Logger.new(STDOUT)
    resultado = []
    precio_final = 0
    ##########################
    # Calculo clúster Productivo
    ##########################
    tipo_cluster_prod = "#{params['tipo_cluster_prod']}" #IKS o OCP
    wn_prod = "#{params['wn_prod']}"
    region_cluster_prod = "#{params['region_cluster_prod']}"
    infra_type_prod = "#{params['infra_type_prod']}"
    flavor_prod = "#{params['flavor_prod']}"

    if (tipo_cluster_prod == 'ocp')
      logger.info("url: #{urlapi}/api/v1/preciocluster?region=#{region_cluster_prod}&wn=#{wn_prod}&flavor=#{flavor_prod}&infra_type=#{infra_type_prod}")
      respuesta_cluster = RestClient.get "#{urlapi}/api/v1/preciocluster?region=#{region_cluster_prod}&wn=#{wn_prod}&flavor=#{flavor_prod}&infra_type=#{infra_type_prod}", {:params => {}}
    end

    if (tipo_cluster_prod == 'iks')
      logger.info("url: #{urlapi}/api/v1/ikspreciocluster?region=#{region_cluster_prod}&wn=#{wn_prod}&flavor=#{flavor_prod}&infra_type=#{infra_type_prod}")
      respuesta_cluster = RestClient.get "#{urlapi}/api/v1/ikspreciocluster?region=#{region_cluster_prod}&wn=#{wn_prod}&flavor=#{flavor_prod}&infra_type=#{infra_type_prod}", {:params => {}}
    end

    cluster_prod = {}
    cluster_prod=JSON.parse(respuesta_cluster.to_s)
    logger.info("RestClient: " +respuesta_cluster.to_s)
    logger.info("JSON: "+ cluster_prod.to_s)
    precio_final=precio_final+cluster_prod[0]["precio"]

    ##########################
    # Calculo clúster DR
    ##########################

    tipo_cluster_dr = "#{params['tipo_cluster_dr']}" #IKS o OCP
    wn_dr = "#{params['wn_dr']}"
    region_cluster_dr = "#{params['region_cluster_dr']}"
    infra_type_dr = "#{params['infra_type_dr']}"
    flavor_dr = "#{params['flavor_dr']}"

    if (tipo_cluster_dr == 'ocp')
      logger.info("url: #{urlapi}/api/v1/preciocluster?region=#{region_cluster_dr}&wn=#{wn_dr}&flavor=#{flavor_dr}&infra_type=#{infra_type_dr}")
      respuesta_cluster = RestClient.get "#{urlapi}/api/v1/preciocluster?region=#{region_cluster_dr}&wn=#{wn_dr}&flavor=#{flavor_dr}&infra_type=#{infra_type_dr}", {:params => {}}
    end

    if (tipo_cluster_dr == 'iks')
      logger.info("url: #{urlapi}/api/v1/ikspreciocluster?region=#{region_cluster_dr}&wn=#{wn_dr}&flavor=#{flavor_dr}&infra_type=#{infra_type_dr}")
      respuesta_cluster = RestClient.get "#{urlapi}/api/v1/ikspreciocluster?region=#{region_cluster_dr}&wn=#{wn_dr}&flavor=#{flavor_dr}&infra_type=#{infra_type_dr}", {:params => {}}
    end

    cluster_dr = {}
    cluster_dr=JSON.parse(respuesta_cluster.to_s)
    logger.info("RestClient: " +respuesta_cluster.to_s)
    logger.info("JSON: "+ cluster_dr.to_s)
    precio_final=precio_final+cluster_dr[0]["precio"]

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
    precio_final = precio_final + (db_etcd[0]["precio"].to_f * 2) #Se multiplica por 2 porque cada cluster tiene su propio db for etcd

    ##########################
    # Calculo Portworx
    ##########################

    region_portworx = "dallas"
    tipo_portworx_prod = infra_type_prod
    wn_portworx_prod = wn_prod

    portworx_prod = {}

    logger.info("url: ")
    respuesta_portworx = RestClient.get "#{urlapi2}/api/v1/portworxprecio?region=#{region_portworx}&tipo=#{tipo_portworx_prod}&workers=#{wn_portworx_prod}"
    portworx_prod = JSON.parse(respuesta_portworx.to_s)
    logger.info("RestClient: " + respuesta_portworx.to_s)
    logger.info("JSON: " + portworx_prod.to_s)
    precio_final = precio_final + portworx_prod[0]["precio"].to_f
    
    ##########################
    # Calculo Portworx
    ##########################

    region_portworx = "dallas"
    tipo_portworx_dr = infra_type_dr
    wn_portworx_dr = wn_dr

    portworx_dr = {}

    logger.info("url: ")
    respuesta_portworx = RestClient.get "#{urlapi2}/api/v1/portworxprecio?region=#{region_portworx}&tipo=#{tipo_portworx_dr}&workers=#{wn_portworx_dr}"
    portworx_dr = JSON.parse(respuesta_portworx.to_s)
    logger.info("RestClient: " + respuesta_portworx.to_s)
    logger.info("JSON: " + portworx_dr.to_s)
    precio_final = precio_final + portworx_dr[0]["precio"].to_f

    ##########################
    # JSON Final
    ##########################
    
    resultado.push(cluster_prod: cluster_prod[0], cluster_dr: cluster_dr[0], portworx_prod:portworx_prod[0], portworx_dr:portworx_dr[0], block_storage: block_storage[0], db_etcd:db_etcd[0], preciototal:precio_final.round(2))
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
      if tipo == 'bm'
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
