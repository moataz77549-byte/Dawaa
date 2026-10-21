import {build} from '../backend/node_modules/esbuild/lib/main.js';
import {fileURLToPath} from 'node:url';
import {copyFile} from 'node:fs/promises';
const root=fileURLToPath(new URL('../',import.meta.url));
await build({absWorkingDir:root,entryPoints:['backend/functions/viewer.js'],bundle:true,minify:true,target:'chrome58',outfile:'app/assets/viewer/viewer.js'});
await copyFile(new URL('../backend/node_modules/three/LICENSE',import.meta.url),new URL('../app/assets/viewer/THREE-LICENSE.txt',import.meta.url));
