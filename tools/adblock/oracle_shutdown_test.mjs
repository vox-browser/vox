import assert from 'node:assert/strict';
import test from 'node:test';
import fs from 'node:fs/promises';
import os from 'node:os';
import path from 'node:path';
import {closeOracleBrowser,requestOracleBrowserClose,parseOracleProcessSnapshot} from './oracle_shutdown.mjs';

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

test('a failed debugger close terminates only the owned browser and rejects its abnormal exit',async()=>{
    const browser=process();
    const snapshot=async()=>browser.signalCode ? [row(90,1)] : [row(10,1),row(90,1)];
    await assert.rejects(closeOracleBrowser(browser,async()=>{throw Error('Debugger closed');},
        {snapshot,pollMs:1}),/exited abnormally: SIGTERM/);
    assert.deepEqual(browser.signals,['SIGTERM']);
});

test('a nonzero browser exit cannot qualify a closed profile after every helper exits',async()=>{
    const browser=process();let closed=false;
    const snapshot=async()=>closed ? [] : [row(10,1),row(11,10)];
    await assert.rejects(closeOracleBrowser(browser,async()=>{closed=true;browser.exitCode=23;},
        {snapshot,pollMs:1}),/exited abnormally: 23/);
    assert.deepEqual(browser.signals,[]);
});

test('a signalled browser exit cannot qualify a profile even with a zero numeric status',async()=>{
    const browser=process();let closed=false;
    const snapshot=async()=>closed ? [] : [row(10,1)];
    await assert.rejects(closeOracleBrowser(browser,async()=>{
        closed=true;browser.exitCode=0;browser.signalCode='SIGKILL';
    },{snapshot,pollMs:1}),/exited abnormally: SIGKILL/);
});

test('process snapshots retain state, creation identity and executable without arguments',()=>{
    const rows=parseOracleProcessSnapshot(' 10 1 S Thu Nov  5 10:00:00 2026 /Applications/Brave Browser.app/Contents/MacOS/Brave Browser\n 11 10 Z Thu Nov  5 10:00:01 2026 <defunct>\n');
    assert.deepEqual(rows,[{pid:10,parent:1,state:'S',started:'Thu Nov 5 10:00:00 2026',
        executable:'/Applications/Brave Browser.app/Contents/MacOS/Brave Browser'},
        {pid:11,parent:10,state:'Z',started:'Thu Nov 5 10:00:01 2026',executable:'<defunct>'}]);
    assert.throws(()=>parseOracleProcessSnapshot('broken process identity'),/Invalid oracle/);
});

test('successful and failed shutdown receipts preserve the observed owned processes',async t=>{
    const directory=await fs.mkdtemp(path.join(os.tmpdir(),'oracle-shutdown-'));
    t.after(()=>fs.rm(directory,{recursive:true,force:true}));
    for(const survives of [false,true]){
        const browser=process();let closed=false;
        const helper={...row(11,10),state:'U',executable:'Brave helper'};
        const snapshot=async()=>closed ? (survives ? [{...helper,parent:1}] : []) : [row(10,1),helper];
        const receiptFile=path.join(directory,String(survives),'shutdown.json');
        const pending=closeOracleBrowser(browser,async()=>{closed=true;browser.exitCode=0;},
            {snapshot,pollMs:1,timeoutMs:20,receiptFile});
        if(survives) await assert.rejects(pending,/owned processes running: 11/);
        else await pending;
        const receipt=JSON.parse(await fs.readFile(receiptFile,'utf8'));
        assert.equal(receipt.status,survives ? 'failed' : 'closed');
        assert.equal(receipt.exit_code,0);
        assert.equal(receipt.signal,null);
        assert.deepEqual(receipt.initial_owned,[row(10,1),helper]);
        assert.deepEqual(receipt.remaining_owned,survives ? [{...helper,parent:1}] : []);
        if(survives) assert.match(receipt.error.message,/owned processes running: 11/);
    }
});

test('a surviving helper fails shutdown instead of declaring a closed profile',async()=>{
    const browser=process();let closed=false;
    const snapshot=async()=>closed ? [row(11,1)] : [row(10,1),row(11,10)];
    await assert.rejects(closeOracleBrowser(browser,async()=>{closed=true;browser.exitCode=0;},
        {snapshot,pollMs:1,timeoutMs:20}),/owned processes running: 11/);
    assert.deepEqual(browser.signals,[]);
});
