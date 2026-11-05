import assert from 'node:assert/strict';
import test from 'node:test';
import {closeOracleBrowser,requestOracleBrowserClose} from './oracle_shutdown.mjs';

const process = () => ({pid:10, exitCode:null, signalCode:null, signals:[],
    kill(signal) {this.signals.push(signal);this.signalCode=signal;}});
const row = (pid,parent,started=String(pid)) => ({pid,parent,started});

test('page and extension debuggers close before the browser close request',async()=>{
    const events=[];
    const control={send:async method=>{events.push(method);},close:()=>events.push('control')};
    await requestOracleBrowserClose(control,{close:()=>events.push('extension')},
        {close:()=>events.push('page')});
    assert.deepEqual(events,['extension','page','Browser.close','control']);
});

test('a rejected close request releases the control connection and retains the error',async()=>{
    const error=Error('Browser debugger closed');let released=false;
    await assert.rejects(requestOracleBrowserClose({send:async()=>{throw error;},
        close:()=>{released=true;}}),value=>value===error);
    assert(released);
});

test('shutdown waits for helpers after their browser parent exits and they are reparented',async()=>{
    const browser=process();let reads=0,closed=false;
    const snapshot=async()=>{
        ++reads;
        if(!closed) return [row(10,1),row(11,10),row(12,11),row(90,1)];
        browser.exitCode=0;
        if(reads<5) return [row(11,1),row(12,11),row(90,1)];
        return [row(90,1)];
    };
    await closeOracleBrowser(browser,async()=>{closed=true;},{snapshot,pollMs:1});
    assert(reads>=5);assert.deepEqual(browser.signals,[]);
});

test('a recycled helper PID does not become owned, nor do its new children',async()=>{
    const browser=process();let closed=false;
    const snapshot=async()=>closed
        ? [row(11,1,'replacement'),row(12,11)] : [row(10,1),row(11,10)];
    await closeOracleBrowser(browser,async()=>{closed=true;browser.exitCode=0;},{snapshot,pollMs:1});
    assert.deepEqual(browser.signals,[]);
});

test('a failed debugger close terminates only the owned browser and still waits',async()=>{
    const browser=process();
    const snapshot=async()=>browser.signalCode ? [row(90,1)] : [row(10,1),row(90,1)];
    await closeOracleBrowser(browser,async()=>{throw Error('Debugger closed');},{snapshot,pollMs:1});
    assert.deepEqual(browser.signals,['SIGTERM']);
});

test('a surviving helper fails shutdown instead of declaring a closed profile',async()=>{
    const browser=process();let closed=false;
    const snapshot=async()=>closed ? [row(11,1)] : [row(10,1),row(11,10)];
    await assert.rejects(closeOracleBrowser(browser,async()=>{closed=true;browser.exitCode=0;},
        {snapshot,pollMs:1,timeoutMs:20}),/owned processes running: 11/);
    assert.deepEqual(browser.signals,[]);
});
