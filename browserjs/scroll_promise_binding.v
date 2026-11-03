module browserjs

import dom

pub type ScrollPromiseResolver = fn (string) ?&dom.Promise
