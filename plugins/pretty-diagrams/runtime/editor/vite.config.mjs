import {defineConfig} from 'vite';
import react from '@vitejs/plugin-react';
export default defineConfig({root:'editor',plugins:[react()],build:{outDir:'../web',emptyOutDir:true}});
