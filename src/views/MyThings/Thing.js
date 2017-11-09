import React, { Component } from 'react';
import uuid from 'uuid';
import { Col, Dropdown, ButtonDropdownMenu, DropdownMenu, ButtonDropdown, DropdownToggle, DropdownItem, Button, Modal, ModalHeader, ModalBody, ModalFooter} from 'reactstrap';
import { Link } from 'react-router-dom';
import {logOut} from '../../utils/AuthService';
import { Combobox } from 'react-input-enhancements';
import {createThing,removeThing,updateThing,installApp} from '../../utils/manifoldSDK';
import { connect } from 'react-redux';
import TestForm from './testForm';
import InnerHTML from 'dangerously-set-inner-html';
import Parser from 'html-react-parser';
import CardReplace from '../../utils/cardReplaceAPI';
import JsxParser from 'react-jsx-parser';
import JournalTemplate from '../Templates/journalTemplate';
import { Chart } from 'react-google-charts';
import ThingFooter from './ThingFooter';
import ThingHeader from './ThingHeader';
import CustomComponentMap from '../Templates/customComponentMap';

const brandPrimary =  '#20a8d8';
const brandSuccess =  '#4dbd74';
const brandInfo =     '#63c2de';
const brandDanger =   '#f86c6b';

class Thing extends Component {
  constructor(props) {
    super(props);

    // handle clicks
    this.handleRemoveClick = this.handleRemoveClick.bind(this);
    this.handleInstallRulesetClick = this.handleInstallRulesetClick.bind(this);
    this.handleCarouselDotClick = this.handleCarouselDotClick.bind(this);
    // modals
    this.toggleRemoveModal = this.toggleRemoveModal.bind(this);
    this.toggleInstallRulesetModal = this.toggleInstallRulesetModal.bind(this);
    // drop downs
    this.toggleInstallRulesetDropdown = this.toggleInstallRulesetDropdown.bind(this);
    this.injectCode = this.injectCode.bind(this);

    //this.appendAppToDotList = this.appendAppToDotList.bind(this);

    this.state = {
      installedApps:[],
      installRulesetDropdownOpen: false,
      removeModal: false,
      installRulesetModal: false,
      rulesetToInstallName: "",
      url: "",
      appsMaxIndex: -1, //-1 indicates no apps are installed, allows the incremental functionality to work
      currentApp: 0,
      value: "DEFAULT INPUT VAL",
      appsToInstallOptions: ["io.picolabs.journal", "io.picolabs.wovyn_device", "io.picolabs.tempTestApp", "io.picolabs.helloWorld"]
    }
  }

  componentWillMount(){
    //query for the discovery and app info
    this.props.dispatch({type: 'DISCOVERY', eci: this.props.eci, pico_id: this.props.id});
  }

  toggleRemoveModal(){
    this.setState({
      removeModal: !this.state.removeModal
    });
  }

  toggleInstallRulesetModal(){
    this.setState({
      installRulesetModal: !this.state.installRulesetModal
    });
  }

  handleRemoveClick(){
    const nameToDelete = this.props.name;
    this.toggleRemoveModal();
    this.props.dispatch({
      type: "command",
      command: removeThing,
      params: [nameToDelete],
      query: { type: 'MANIFOLD_INFO' }
    });
  }

  handleInstallRulesetClick(){
    console.log(this.props.eci);
    console.log(this.state.rulesetToInstallName);
    if (this.state.rulesetToInstallName != null && this.state.rulesetToInstallName != "") {
      this.props.dispatch({
        type: "command",
        command: installApp,
        params: [this.props.eci, this.state.rulesetToInstallName],
        query: { type: 'DISCOVERY', eci: this.props.eci, pico_id: this.props.id },
        delay: 500
      });
      this.toggleInstallRulesetModal();

    }else{
      alert("Please select a ruleset to install or hit cancel.");
    }
  }

  handleCarouselDotClick(index){
    this.setState({
      currentApp: index
    });
    console.log("HELLO FROM DOT: " + index );
  }

  toggleInstallRulesetDropdown(){
    this.setState({
      installRulesetDropdownOpen: !this.state.installRulesetDropdownOpen
    });
  }

  injectCode(){
    const thingIdentity = this.props.identities[this.props.id];
    if(thingIdentity && thingIdentity[this.state.currentApp]){
      const currentAppInfo = thingIdentity[this.state.currentApp];
      if(currentAppInfo.options){
        var bindings;
        if(currentAppInfo.options.bindings){
          bindings = currentAppInfo.options.bindings;
          bindings.eci = this.props.eci;
          bindings.id = this.props.id;
        }else{
          return (<div>Missing bindings from the pico!</div>)
        }
        const CustomComponent = CustomComponentMap[currentAppInfo.options.rid];
        if(CustomComponent){
          return (
            <div>
              <CustomComponent {...bindings} />
            </div>
          )
        }else{
          return (
            <div>
              Error loading the custom component!
            </div>
          )
        }
      }
    }

    //have a default return
    return (
      <div>
        There are no apps currently installed on this Thing!
      </div>
    )
  }

  renderRemoveModal(){
    return (
      <Modal isOpen={this.state.removeModal} className={'modal-danger'}>
        <ModalHeader >Delete a Thing</ModalHeader>
        <ModalBody>
          Are you sure you want to delete {this.props.name}?
        </ModalBody>
        <ModalFooter>
          <Button color="danger" onClick={this.handleRemoveClick}>Delete Thing</Button>{' '}
          <Button color="secondary" onClick={this.toggleRemoveModal}>Cancel</Button>
        </ModalFooter>
      </Modal>
    )
  }

  renderInstallModal(){
    return (
      <Modal isOpen={this.state.installRulesetModal} className={'modal-info'}>
        <ModalHeader >Install an App</ModalHeader>
        <ModalBody>
          <div className="form-group">
            <label> Select a ruleset to install:</label>
                <Col xs={6}>
                  <Combobox defaultValue={this.state.value}
                            options={this.state.appsToInstallOptions}
                            onSelect={(element) => this.setState({ rulesetToInstallName: element})}
                            autosize
                            autocomplete>
                    {(inputProps, { matchingText, width }) =>
                      <input {...inputProps} type='text' placeholder="Select APP" />
                    }
                  </Combobox>
                </Col>
          </div>
        </ModalBody>
        <ModalFooter>
          <Button color="info" onClick={this.handleInstallRulesetClick}>Install it</Button>
          <Button color="secondary" onClick={this.toggleInstallRulesetModal}>Cancel</Button>
        </ModalFooter>
      </Modal>
    )
  }

  render(){
    return (
      <div className={"card"} style={{  height: "inherit", width: "inherit"}}>
        <ThingHeader name={this.props.name} openRemoveModal={this.toggleRemoveModal} openInstallModal={this.toggleInstallRulesetModal}/>
        {this.renderInstallModal()}
        {this.renderRemoveModal()}

        <div className="card-block" style={{"textOverflow": "clip", overflow: "hidden"}}>
          {this.injectCode()}
        </div>
        <ThingFooter dotClicked={this.handleCarouselDotClick} installedApps={this.props.identities[this.props.id]} currentApp={this.state.currentApp}/>

      </div>
    );
  }
}
// ID: {this.props.id} <br/>
// ECI: {this.props.eci}<br/>
// PARENT_ECI: {this.props.parent_eci}
const mapStateToProps = state => {
  if(state.identities){
    var id = state.manifoldInfo.things.things.children[0].id
    var thisPicoAppsMetadata = state.identities[id]
    return {
       identities: state.identities,
    }
  }else{
    return {}
  }
}


export default connect(mapStateToProps)(Thing);
