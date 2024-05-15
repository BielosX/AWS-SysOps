import axios from "axios"

const METADATA_URL = 'http://169.254.169.254/latest'
const TOKEN_TTL_HEADER = 'X-aws-ec2-metadata-token-ttl-seconds'
const TOKEN_HEADER = 'X-aws-ec2-metadata-token'

const getMetadata = async () => {
    const token = await axios.put(`${METADATA_URL}/api/token`, null, {
        headers: {
            [TOKEN_TTL_HEADER]: '21600'
        }
    })
    const config = {
        headers: {
            [TOKEN_HEADER]: token.data
        }
    }
    const instanceId = axios.get(`${METADATA_URL}/meta-data/instance-id`, config)
    const availabilityZone = axios.get(`${METADATA_URL}/meta-data/placement/availability-zone`, config)
    return {
        'instanceId': (await instanceId).data,
        'availabilityZone': (await availabilityZone).data
    }
}

export const metadata = await getMetadata()