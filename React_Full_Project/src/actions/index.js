import axios from 'axios';
import { HOST, CLIENT_KEY, CLIENT_SECRET } from '../utils/config';
import {getCallbackURL,getHostname,getClientSecret} from '../utils/AuthService';
export const ACCESS_TOKEN = 'access_token';

export function getAccessToken(code){
  const body = {
    "grant_type": "authorization_code",
    "redirect_uri": getCallbackURL(),
    "client_id": CLIENT_KEY,
    "code": code,
    "client_secret": getClientSecret()
  };
  const request = axios.post(`http://${getHostname()}/token`,body);


  return {
    type: ACCESS_TOKEN,
    payload: request
  };
}
