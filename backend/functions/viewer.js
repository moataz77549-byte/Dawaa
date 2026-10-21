import * as THREE from 'three';
import {GLTFLoader} from 'three/addons/loaders/GLTFLoader.js';
import {OrbitControls} from 'three/addons/controls/OrbitControls.js';
try {
 const renderer=new THREE.WebGLRenderer({antialias:true});
 renderer.setPixelRatio(Math.min(window.devicePixelRatio,2));document.body.appendChild(renderer.domElement);
 const scene=new THREE.Scene();scene.background=new THREE.Color('#f5f8f7');
 const camera=new THREE.PerspectiveCamera(45,1,.01,100);camera.position.set(3,2,4);
 scene.add(new THREE.HemisphereLight(0xffffff,0x123f42,3));
 const light=new THREE.DirectionalLight(0xffffff,3);light.position.set(3,5,2);scene.add(light);
 const controls=new OrbitControls(camera,renderer.domElement);controls.enableDamping=true;controls.minDistance=2;controls.maxDistance=10;
 window.resetModel=()=>{camera.position.set(3,2,4);controls.target.set(0,0,0);controls.update();};
 const resize=()=>{const w=window.innerWidth,h=window.innerHeight;renderer.setSize(w,h);camera.aspect=w/h;camera.updateProjectionMatrix();};resize();window.addEventListener('resize',resize);
 const started=performance.now();
 new GLTFLoader().load('/model.glb',g=>{
   try {
     scene.add(g.scene);renderer.render(scene,camera);
     if(renderer.getContext().isContextLost()||renderer.info.render.calls<1)throw Error('No rendered geometry');
     window.ViewerStatus?.postMessage('metrics:'+JSON.stringify({loadAndFirstRenderMs:Math.round(performance.now()-started),drawCalls:renderer.info.render.calls,geometries:renderer.info.memory.geometries}));
     window.ViewerStatus?.postMessage('ready');
   }catch(e){window.ViewerStatus?.postMessage('error');}
 },undefined,()=>window.ViewerStatus?.postMessage('error'));
 renderer.setAnimationLoop(()=>{controls.update();renderer.render(scene,camera);});
 document.addEventListener('visibilitychange',()=>{if(document.hidden)renderer.setAnimationLoop(null);else renderer.setAnimationLoop(()=>{controls.update();renderer.render(scene,camera);});});
}catch(e){window.ViewerStatus?.postMessage('error');}
