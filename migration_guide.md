# Chewy 5 to 6

It's a documentation stub, it'll be developed during the process of preparing chewy for ES6 compatibility.

When you want to prepare your application for chewy6:

* replace field with `{ type: 'string', index: 'not_analyzed'}` by `{type: 'keyword'}`
* replace field with `{ type: 'string', index: 'analyzed'}` by `{type: 'text'}`
