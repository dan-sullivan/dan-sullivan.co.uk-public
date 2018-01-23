# Dan-Sullivan.co.uk

[dan-sullivan.co.uk](dan-sullivan.co.uk) is my personal site, used to demonstrate familiarity with a variety of technologies and concepts. Similarly, this repository contains and documents the various code and configuration used to build the site.

## The Premise

As the goal is to demonstrate common DevOps concepts like infrastructure as code and automation, the site content is extremely simple. Hitting the root of the site will redirect you to the same page served by different methods. The intention being to grow the methods.

AWS Lambda
AWS S3

## Infrastucture

Infrastructure is built where possible with Terraform and hosted in AWS.

Diagram

## Continuous Integration



## Frontend

### Overview
[Grunt](https://gruntjs.com) is used to pull all the html, css and javascript together and to prepare the different versions of the site for distribution.

Watch and Livereload plugins assist with rapid development.

[Skeleton-Sass](https://github.com/WhatsNewSaes/Skeleton-Sass), the [Sass](http://sass-lang.com) version of the simple, responsive [Skeleton CSS](http://getskeleton.com) framework was chosen to keep things very light. No need for bootstrap, jquery here. 

[Sass](http://sass-lang.com) is used to assist with CSS development, particularly useful for adding variables.


### Infrastructure Diagram Animation
The infrastructure diagram was built with Lucidchart. I then exported it as an SVG, manually grouped the elements and paths into layers with Inkscape and again saved as an optimised SVG (with a viewport to enable scaling). The fill and stroke attributes were the converted to classes with some regex and Vim search/replace. This will then enable me to change them with standard CSS and add them to the Sass CSS build.  

```
Stroke and Fill:
:%s/\v(stroke\=\"(\#.{6}|none)\")(.*)(fill\=\"(\#.{6}|none)\")/\3 class="stroke-\2 fill-\5"/g

Note: shouldnt need the nested capture groups on that actually.

Fills only:
:%s/\vfill\=\"(\#.{6}|none)\"/class="fill-\1"/g

Strokes only: 
:%s/\vstroke\=\"(\#.{6}|none)\"/class="stroke-\1"/g
```

Using Sass, the various original colours were then mapped to Solarized options via the classes created early.

Animation was done by hand with CSS Keyframes.


# Further Credits

- The popular [Solarized](http://ethanschoonover.com/solarized) colour scheme is used, chosen simply because it matches my current terminal colours. 
- Github user frebro had already created a [Sass module](https://github.com/frebro/sass-solarized/blob/master/_solarized.scss) to map the colours to variables.
- Typed.js



# [Skeleton-Sass](http://getskeleton.com)

Skeleton-Sass is the (un)official Sass version of [Dave Gamache's](https://twitter.com/dhg) Skeleton Framework. It currently featues a stable version of Skeleton 2.0.4

-----

Skeleton is a simple, responsive boilerplate to kickstart any responsive project.

Check out <http://getskeleton.com> for documentation and details.

## Getting started

### Install Global Dependencies
  * [Node.js](http://nodejs.org)
  * [bower](http://bower.io): `[sudo] npm install bower -g`
  * [grunt.js](http://gruntjs.com): `[sudo] npm install -g grunt-cli`

### Install Local Dependencies
  * [Download zip](https://github.com/whatsnewsaes/Skeleton-Sass/archive/master.zip), [clone the repo](github-mac://openRepo/https://github.com/whatsnewsaes/Skeleton-Sass) or `bower install skeleton-scss` from your terminal
  * cd to project folder
  * run `[sudo] npm install` (first time users)
  * run `grunt` (to watch and compile sass files)

### What's in the download?

The download includes Skeleton's CSS, ~~Normalize CSS as a reset,~~ a sample favicon, and an index.html as a starting point.

```
skeleton/
├── index.html
├── scss/
│   └── skeleton.scss
├── images/
│   └── favicon.png
├── package.json
├── Gruntfile.js
└── README.md

```

### Contributions
The goal of Skeleton-Sass is to have a mirrored Sass repository of Skeleton. In order to keep the integrity of the original Skeleton framework, I cannot accept any features or functionality outside the original implementation of [Dave Gamache's](https://twitter.com/dhg) [Skeleton Framework](https://github.com/dhg/Skeleton). If you would like to see features, functionality, or extensions outside of the original please make a PR / or issue on the original skeleton framework.

If you have sass improvements, additional mixins, or other helpful sass techniques that stay within the original codebase. Feel free to make a pull request!

### Why it's awesome

Skeleton is lightweight and simple. It styles only raw HTML elements (with a few exceptions) and provides a responsive grid. Nothing more.
- Minified, it's less than a kb
- It's a starting point, not a UI framework
- ~~No compiling or installing...just vanilla CSS~~


## Browser support

- Chrome latest
- Firefox latest
- Opera latest
- Safari latest
- IE latest

The above list is non-exhaustive. Skeleton works perfectly with almost all older versions of the browsers above, though IE certainly has large degradation prior to IE9.


## License

All parts of Skeleton-sass are free to use and abuse under the [open-source MIT license](http://opensource.org/licenses/mit-license.php).


## Colophon

Skeleton was built using [Sublime Text 3](http://www.sublimetext.com/3) and designed with [Sketch](http://bohemiancoding.com/sketch). The typeface [Raleway](http://www.google.com/fonts/specimen/Raleway) was created by [Matt McInerney](http://matt.cc/) and [Pablo Impallari](http://www.impallari.com/). Code highlighting by Google's [Prettify library](https://code.google.com/p/google-code-prettify/). Icons in the header of the documentation are all derivative work of icons from [The Noun Project](thenounproject.com). [Feather](http://thenounproject.com/term/feather/22073) by Zach VanDeHey, [Pen](http://thenounproject.com/term/pen/21163) (with cap) by Ed Harrison, [Pen](http://thenounproject.com/term/pen/32847) (with clicker) by Matthew Hall, and [Watch](http://thenounproject.com/term/watch/48015) by Julien Deveaux.


## Acknowledgement

Skeleton was created by [Dave Gamache](https://twitter.com/dhg) for a better web.

Skeleton-Sass was created by [Seth Coelen](http://sethcoelen.com) for a better Skeleton.

<a href='https://ko-fi.com?i=2446A87JJ08CZ' target='_blank'>
<img style='border:0px;width:100px;' src='https://az743702.vo.msecnd.net/cdn/btn1.png' border='0' alt='Buy me a coffee at ko-fi.com' />
</a> 

