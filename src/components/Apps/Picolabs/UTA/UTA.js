import React, { Component } from 'react';
import SearchBar from './SearchBar';
import RouteList from './RouteList';
import GMap from './GMap';
//import { GOOGLE_MAP_KEY } from '../../../../utils/config';
import './UTA.css';

class UTA extends Component {
  constructor(props) {
    super(props);
    this.state = {
      stopInfo: [],
      stopCode: 0
    }
    this.searchStop = this.searchStop.bind(this);
  }

  searchStop(sCode) {

    const promise = this.props.manifoldQuery({
      rid: "io.picolabs.uta",
      funcName: "stopCode",
      funcArgs: {
        code: sCode
      }
    });

      promise.then((resp) => {this.setState({stopInfo : resp.data, stopCode : sCode});}).catch((e) => {
        console.error("Error loading uta: ", e);
      });
  }

  camelCase(stopName) {
    var charTemp = "";
    var toRet = "";

    for (var i = 0; i < stopName.length; i++) {
      if(i === 0) charTemp = stopName.charAt(i).toUpperCase();
      else if(stopName.charAt(i-1) === ' ') charTemp = stopName.charAt(i).toUpperCase();
      else charTemp = stopName.charAt(i).toLowerCase();
      toRet += charTemp;
    }
    return toRet;
  }

  render() {
    const url = `https://maps.googleapis.com/maps/api/js?key=${process.env.REACT_APP_GOOGLE_MAP_KEY}&v=3.exp&libraries=geometry,drawing,places`;
    return (
      <div className='shortenedWidth'>
        {this.state.stopInfo.name && <h3>{this.camelCase(this.state.stopInfo.name)}</h3>}

        {this.state.stopInfo.lat && this.state.stopInfo.lon && <GMap
          lat={parseFloat(this.state.stopInfo.lat)}
          lon={parseFloat(this.state.stopInfo.lon)}
          isMarkerShown
          googleMapURL={url}
          loadingElement={<div style={{ height: `100%` }} />}
          containerElement={<div style={{ height: `300px` }} />}
          mapElement={<div style={{ height: `100%` }} />}/>}

        {this.state.stopInfo.routes_array && <br></br> && <RouteList Routes={this.state.stopInfo.routes_array} />}
        <br></br>
        <SearchBar search={this.searchStop}/>

      </div>
    )
  }
}

export default UTA;
