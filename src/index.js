import './main.css';
import { Elm } from './Main.elm';
import * as serviceWorker from './serviceWorker';

var app = Elm.Main.init({
  node: document.getElementById('root')
});

var socket = new WebSocket('ws://vord1-elm.free.beeceptor.com')

socket.addEventListener("screens received", function(screens) {
  app.ports.onScreensReceived.send(screens);
}, false);

// If you want your app to work offline and load faster, you can change
// unregister() to register() below. Note this comes with some pitfalls.
// Learn more about service workers: https://bit.ly/CRA-PWA
serviceWorker.unregister();
