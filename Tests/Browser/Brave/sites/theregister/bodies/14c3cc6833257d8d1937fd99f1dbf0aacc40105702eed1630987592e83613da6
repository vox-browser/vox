/**
 * JWTCookie - Get data from JWT token
 * (c) Publish Lab AS 2020
 */

if (!window.Dac) window.Dac = {}
var Dac = window.Dac;
Dac.JWTCookie = class {

    constructor(item) {
        this.debug = item.debug || false;
    }

    log(msg) {
        if (!this.debug) { return; }
        console.log('JWT cookie handler:', msg);
    }

    get(key) {
        this.cookie = this.cookie || this.getCookie();
        if (!this.cookie || !this.cookie.hasOwnProperty(key)) 
            return '';
        return this.cookie[key] || '';
    }

    getCookie() {   
        const cookie = this.getCookieValue('Paywall-Token');
        if(!cookie) {
            this.log('No Paywall token found in cookies');
            return '';
        }
        return parseJwt(cookie);

        function parseJwt(token) {
            try {
                var base64Url = token.split('.')[1];
                var base64 = base64Url.replace(/-/g, '+').replace(/_/g, '/');
                var jsonPayload = decodeURIComponent(atob(base64).split('').map(function (c) {
                    return '%' + ('00' + c.charCodeAt(0).toString(16)).slice(-2);
                }).join(''));
                return JSON.parse(jsonPayload);
            } catch(e) {
                this.log('Error parsing cookie, cookie probably not of type JWT token');
                return '';
            }
        };
    }

    getCookieValue(a) {
        var b = document.cookie.match('(^|;)\\s*' + a + '\\s*=\\s*([^;]+)');
        return b ? b.pop() : '';
    }

    isAuthenticated() {
        if (this.get('userid') || this.get('sub')) { // Subscriber is set
            var exp = this.get('exp');
            var softExp = this.get('softExp');
            if (exp && softExp && Date.now) {
                exp = parseInt(exp);
                softExp = parseInt(softExp);
                var now = Math.floor(Date.now() / 1000);
                if (exp && exp > now && softExp && softExp > now) {
                    return true;
                }
            }
        }
        return false;
    }
}