# restman.nvim

Restfully manage your requests

## 🧾 Description

This is barebones plugin which executes a shell commands in a paragraph and if the `stdout` happens to
be a json output, formats it and sets the filetype to the buffer

## ✨ Features

- Generic approach. Allows to execute any shell command, not only pure `curl`
- Strip comments. Comment out query lines and it still will be executed correctly
- Sticky headers. Display response headers in a sticky buffer

## 🛑 Drawbacks

- Security issues. The command is not verified for being a legitimate `curl` request
- Semicolon can't be used in a request for now since the paragraph is passed into `stdin` of `/bin/sh`
- Requires headers to operate. The plugin decides if `stdout` is `JSON` if there is `content-type: application/json` response header in the `stderr`

## 👀 Demonstration

![restman](https://github.com/user-attachments/assets/43c761ac-2935-4637-88a0-d821a7d62f59)

## 🔍 Alternatives

- https://github.com/michaelb/sniprun
- https://github.com/rest-nvim/rest.nvim
- https://github.com/Orange-OpenSource/hurl
