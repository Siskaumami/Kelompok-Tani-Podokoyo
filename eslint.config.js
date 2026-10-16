import js from '@eslint/js';
import ts from 'typescript-eslint';
export default ts.config({ignores:['dist/**','node_modules/**']},js.configs.recommended,...ts.configs.recommended,{files:['apps/web/public/*.js'],languageOptions:{globals:{self:'readonly',caches:'readonly',URL:'readonly',fetch:'readonly',document:'readonly',location:'readonly'}}},{files:['**/*.ts','**/*.tsx'],rules:{'@typescript-eslint/no-explicit-any':'off','@typescript-eslint/no-unused-vars':['error',{argsIgnorePattern:'^_',varsIgnorePattern:'^_'}],'no-empty':'error'}});
