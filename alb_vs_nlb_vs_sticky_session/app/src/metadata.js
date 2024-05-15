import axios from "axios"
import * as R from "ramda"
import {logger} from "./logger";

const METADATA_SERVICE = 'http://169.254.169.254/latest'
const METADATA_URL = `${METADATA_SERVICE}/meta-data`
const TOKEN_URL = `${METADATA_SERVICE}/api/token`
const TOKEN_TTL_HEADER = 'X-aws-ec2-metadata-token-ttl-seconds'
const TOKEN_HEADER = 'X-aws-ec2-metadata-token'

const getConfig = (token) => {
    return {
        headers: {
            [TOKEN_HEADER]: token
        }
    }
}

const getMacs = async (config) => {
    const macsResponse = await axios.get(`${METADATA_URL}/network/interfaces/macs`, config)
    return macsResponse.data.split('\n')
}

const getPrivateIPs = async (config, mac) => {
    const url = `${METADATA_URL}/network/interfaces/macs/${mac}/local-ipv4s`
    const ipsResponse = await axios.get(url, config)
    return ipsResponse.data.split('\n')
}

const getNetworkInterface = async (config, mac) => {
    const prefix = `${METADATA_URL}/network/interfaces/macs/${mac}`
    const interfaceId = axios.get(`${prefix}/interface-id`, config)
    const deviceNumber = axios.get(`${prefix}/device-number`, config)
    const subnetId = axios.get(`${prefix}/subnet-id`, config)
    const privateIPs = getPrivateIPs(config, mac)
    return {
        'interfaceId': (await interfaceId).data,
        'deviceName': `eth${(await deviceNumber).data}`,
        'subnetId': (await subnetId).data,
        'privateIPs': await privateIPs
    }
}

const getNetworkInterfaces = async (config) => {
    const macs = await getMacs(config)
    const interfaces = R.map(m => getNetworkInterface(config, m), macs)
    return await Promise.all(interfaces)
}

const getMetadata = async () => {
    const token = await axios.put(TOKEN_URL, null, {
        headers: {
            [TOKEN_TTL_HEADER]: '21600'
        }
    })
    const config = getConfig(token.data)
    const instanceId = axios.get(`${METADATA_URL}/instance-id`, config)
    const availabilityZone = axios.get(`${METADATA_URL}/placement/availability-zone`, config)
    const meta = {
        'instanceId': (await instanceId).data,
        'availabilityZone': (await availabilityZone).data,
        'networkInterfaces': await getNetworkInterfaces(config)
    }
    logger.info(`Metadata fetched ${meta}`)
    return meta
}

export const metadata = await getMetadata()