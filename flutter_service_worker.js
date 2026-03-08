'use strict';
const MANIFEST = 'flutter-app-manifest';
const TEMP = 'flutter-temp-cache';
const CACHE_NAME = 'flutter-app-cache';

const RESOURCES = {".git/COMMIT_EDITMSG": "efb610e1d1759f1319b5c88457bfa373",
".git/config": "22cd1f5f958b1d994c19d0d73e52e7de",
".git/description": "a0a7c3fff21f2aea3cfa1d0316dd816c",
".git/FETCH_HEAD": "811a4a07bd63c9957b7a72c54cbdfb8d",
".git/gk/config": "bf1bc811ecf3cd43c1dff83403d2dcb6",
".git/HEAD": "5ab7a4355e4c959b0c5c008f202f51ec",
".git/hooks/applypatch-msg.sample": "ce562e08d8098926a3862fc6e7905199",
".git/hooks/commit-msg.sample": "579a3c1e12a1e74a98169175fb913012",
".git/hooks/fsmonitor-watchman.sample": "a0b2633a2c8e97501610bd3f73da66fc",
".git/hooks/post-update.sample": "2b7ea5cee3c49ff53d41e00785eb974c",
".git/hooks/pre-applypatch.sample": "054f9ffb8bfe04a599751cc757226dda",
".git/hooks/pre-commit.sample": "5029bfab85b1c39281aa9697379ea444",
".git/hooks/pre-merge-commit.sample": "39cb268e2a85d436b9eb6f47614c3cbc",
".git/hooks/pre-push.sample": "2c642152299a94e05ea26eae11993b13",
".git/hooks/pre-rebase.sample": "56e45f2bcbc8226d2b4200f7c46371bf",
".git/hooks/pre-receive.sample": "2ad18ec82c20af7b5926ed9cea6aeedd",
".git/hooks/prepare-commit-msg.sample": "2b5c047bdb474555e1787db32b2d2fc5",
".git/hooks/push-to-checkout.sample": "c7ab00c7784efeadad3ae9b228d4b4db",
".git/hooks/sendemail-validate.sample": "4d67df3a8d5c98cb8565c07e42be0b04",
".git/hooks/update.sample": "647ae13c682f7827c22f5fc08a03674e",
".git/index": "67314459a1d57a402c06811406ee83c0",
".git/info/exclude": "036208b4a1ab4a235d75c181e685e5a3",
".git/logs/HEAD": "357f3f2fe7eb0f5df8e87cb57eb275a3",
".git/logs/refs/heads/gh-pages": "357f3f2fe7eb0f5df8e87cb57eb275a3",
".git/logs/refs/remotes/origin/gh-pages": "015f2382e144deb79a1ee8f2670938c5",
".git/objects/02/1d4f3579879a4ac147edbbd8ac2d91e2bc7323": "9e9721befbee4797263ad5370cd904ff",
".git/objects/08/4cdabd104ac615aae3f9e91dbbc6f6d02451b7": "660ca518331728bbcaa5dca522143407",
".git/objects/13/75df894001b6d9c83ae9b85d1336dfb41fabce": "a5d03957fc0f5b65b1430a1cad0351d2",
".git/objects/1d/4b2e0d4875cf73216f41675ec112b90a1940e7": "edfcde672658ad9823630c6d031a4e33",
".git/objects/20/3a3ff5cc524ede7e585dff54454bd63a1b0f36": "4b23a88a964550066839c18c1b5c461e",
".git/objects/21/b771ce92ad9cbf831e4db40e874139319bf356": "820e65b56b4644c8ae0fe063fad268df",
".git/objects/21/e99e92fb8c7f98ef77bcdd6133ef5fd89a4cb4": "186d6f78174c9e3895543938faa9ad19",
".git/objects/28/b86856e016c55993cf794f56dc25604e79f5b2": "c6ca263a51b6b40b34280407ce25dcac",
".git/objects/29/f22f56f0c9903bf90b2a78ef505b36d89a9725": "e85914d97d264694217ae7558d414e81",
".git/objects/30/c2450b0e8c16d6c65a0b56ddf67d2ac3295f9b": "f918fecd45f01f590c79f5860574c5ce",
".git/objects/46/4ab5882a2234c39b1a4dbad5feba0954478155": "2e52a767dc04391de7b4d0beb32e7fc4",
".git/objects/47/5be2ce1cae85f1d3897038e143732dfabb58d2": "3a4c9e4b1fab3c7ef24fbdeb8a148427",
".git/objects/4d/8e1cd210254cf4aa803f35ce5d87f7f79df21b": "624c14d3c5a80796dae1b775181b6106",
".git/objects/4d/bf9da7bcce5387354fe394985b98ebae39df43": "534c022f4a0845274cbd61ff6c9c9c33",
".git/objects/4e/558701c202efdc99bcff2336620f148e1bfd9a": "413665a6ae27dd5eb22e40fb0fff036e",
".git/objects/4f/fbe6ec4693664cb4ff395edf3d949bd4607391": "2beb9ca6c799e0ff64e0ad79f9e55e69",
".git/objects/51/9d785f8ebcbfb160e83f45198bca0d253eaee0": "364491fe7461d1d5d356c79b5caba624",
".git/objects/57/1a6c072fbcb0fd8a9714e22a0322900c45d1ba": "855b09e0f9e71cbf6307a1d9f67f1aa0",
".git/objects/5b/a71f6dcb726a5e105e66e3095b64929b900578": "3c063e71df4757321ebda2fbf789b2a7",
".git/objects/5b/d1db06ecd28b82fed726eadcdaea917ba8dbb1": "a4d1ac386eb517446d2ebd75a21be33d",
".git/objects/62/54c85bc8d01ce92402c775583c8e738034b519": "19635412bafd1d373b6f3a5ce50e26a7",
".git/objects/6b/2b8b24d5d49ce7dbd9b60228052b606bc1b759": "b75a16b3b6b4ae90043fea6e5d99de74",
".git/objects/6b/9862a1351012dc0f337c9ee5067ed3dbfbb439": "85896cd5fba127825eb58df13dfac82b",
".git/objects/72/357192809549f13c7d70cd9fad85076281b0af": "1bf00099f57429cfd8f52c3cb106bc55",
".git/objects/75/224030d145fa4315b5616d862440dd42c6ed69": "8fae86c5edff04ca22805b80ab15186f",
".git/objects/76/639813a0d44293f753414e25bddb7168d7633d": "ec7f0839050b7e963b759dc6cfe07bdf",
".git/objects/77/d85bdecc895f2b757a017886a3694228baf83c": "ca5fc8b31fda64d7dca8b4a1df739f9d",
".git/objects/78/38f314c282f91329292792c98955d7161e401f": "ace7ec076c431afe37d241cd6ba01d8c",
".git/objects/7a/6c1911dddaea52e2dbffc15e45e428ec9a9915": "f1dee6885dc6f71f357a8e825bda0286",
".git/objects/83/6d347245c1aea68269da1aeb2839f5b96a8431": "f94e09a81e6b9bf9558e0d8f1f9e989e",
".git/objects/84/5371cd70a012671ee42e6a3be3b175b3dfc56a": "b3c183b6378d21e7549d817ba7886b6d",
".git/objects/84/e90e4aabf029350cdf0092630b26345246bed2": "25ba6154902d009e43a50569f6f29dc6",
".git/objects/88/cfd48dff1169879ba46840804b412fe02fefd6": "e42aaae6a4cbfbc9f6326f1fa9e3380c",
".git/objects/8a/aa46ac1ae21512746f852a42ba87e4165dfdd1": "1d8820d345e38b30de033aa4b5a23e7b",
".git/objects/94/2673907a804a42257744d24f372845bdecf3e3": "5207ac2e2580000d8184114b5e8c0819",
".git/objects/94/8b37337e8e219493b4682373c66d424eb71272": "bb2a086151b955518502fff9a7592a72",
".git/objects/96/ba3a980afd2c57f3817a35438d1b930791cc35": "e2ba3eac79feddad6079cbda8e7fa3d0",
".git/objects/98/0d49437042d93ffa850a60d02cef584a35a85c": "8e18e4c1b6c83800103ff097cc222444",
".git/objects/9b/3ef5f169177a64f91eafe11e52b58c60db3df2": "91d370e4f73d42e0a622f3e44af9e7b1",
".git/objects/9b/dea851289bffd518640ac957a99ef54dd01dd6": "897b9f615cbdc248d8264b8c30e8360b",
".git/objects/9e/3b4630b3b8461ff43c272714e00bb47942263e": "accf36d08c0545fa02199021e5902d52",
".git/objects/ae/e5b71bb809fde89a609b672633932596bc11e5": "93ff856764792e65211bd015ab24ec6c",
".git/objects/b2/b0b44a46d4169338b499dc4f1a3a7ca0e98751": "1eddfbccb372d72d0fabddf82816c256",
".git/objects/b6/b8806f5f9d33389d53c2868e6ea1aca7445229": "b14016efdbcda10804235f3a45562bbf",
".git/objects/b7/49bfef07473333cf1dd31e9eed89862a5d52aa": "36b4020dca303986cad10924774fb5dc",
".git/objects/b9/2a0d854da9a8f73216c4a0ef07a0f0a44e4373": "f62d1eb7f51165e2a6d2ef1921f976f3",
".git/objects/b9/c344664e80e2e69364e10c9e3a92ff5d9fc277": "7e378ad419c26ebdf28d6a928508c8ef",
".git/objects/bc/3ee2d82429ddc11af64b4d355724fe17da1f2e": "93f2267aafd753f73e5b387b67fb6d7b",
".git/objects/c1/01dfde7ac84e3b4550ac04ecd15529a7d3de88": "53c74d258111b619a3cd44d1ceabaf3f",
".git/objects/c4/016f7d68c0d70816a0c784867168ffa8f419e1": "fdf8b8a8484741e7a3a558ed9d22f21d",
".git/objects/c5/89c1b9ed30a43f02e718fa52eb293cc8f559f1": "aff46dd8c0f9c6be653738a8fd496db4",
".git/objects/c8/35bb00cb0e8d0e3264e88b3b123cee7a09f6dc": "bb4f66a60ffd5641a9491db04c9d27f4",
".git/objects/ca/3bba02c77c467ef18cffe2d4c857e003ad6d5d": "316e3d817e75cf7b1fd9b0226c088a43",
".git/objects/d4/3532a2348cc9c26053ddb5802f0e5d4b8abc05": "3dad9b209346b1723bb2cc68e7e42a44",
".git/objects/d5/13666945f6c0b69c221b37931419a6bf797ff1": "927ffbef4c3451e9ece90516887693d5",
".git/objects/d6/9c56691fbdb0b7efa65097c7cc1edac12a6d3e": "868ce37a3a78b0606713733248a2f579",
".git/objects/d7/7cfefdbe249b8bf90ce8244ed8fc1732fe8f73": "9c0876641083076714600718b0dab097",
".git/objects/d8/eb8c2f479508e8e46603fdc6d2107c4798eebd": "3b612a955817399671318fc721c9ea02",
".git/objects/e3/e9ee754c75ae07cc3d19f9b8c1e656cc4946a1": "14066365125dcce5aec8eb1454f0d127",
".git/objects/e8/314e35dcee5100be4bfb6f7b09113cc4103235": "385d6576e6d4f7916b1973a74f492372",
".git/objects/e9/94225c71c957162e2dcc06abe8295e482f93a2": "2eed33506ed70a5848a0b06f5b754f2c",
".git/objects/eb/9b4d76e525556d5d89141648c724331630325d": "37c0954235cbe27c4d93e74fe9a578ef",
".git/objects/ed/208896bac989bb600f1c6b168008f1881a41c6": "c08d5eb9864f4d3466b607cb963e359c",
".git/objects/ed/b55d4deb8363b6afa65df71d1f9fd8c7787f22": "886ebb77561ff26a755e09883903891d",
".git/objects/f2/04823a42f2d890f945f70d88b8e2d921c6ae26": "6b47f314ffc35cf6a1ced3208ecc857d",
".git/objects/f5/72b90ef57ee79b82dd846c6871359a7cb10404": "e68f5265f0bb82d792ff536dcb99d803",
".git/objects/f6/b0fcac4bcac8df851d096ec206a49f5dc68efe": "d28be809dc3ef5db4e873a78ecc6243e",
".git/objects/fe/3b987e61ed346808d9aa023ce3073530ad7426": "dc7db10bf25046b27091222383ede515",
".git/ORIG_HEAD": "e7f95e5c89a14ccacaa637fdb8b40fdb",
".git/refs/heads/gh-pages": "e7f95e5c89a14ccacaa637fdb8b40fdb",
".git/refs/remotes/origin/gh-pages": "e7f95e5c89a14ccacaa637fdb8b40fdb",
"assets/AssetManifest.bin": "27b4a056543a8eadb21257623abd24d6",
"assets/AssetManifest.bin.json": "4c61cb752cefe121eabf995c87d91db0",
"assets/AssetManifest.json": "8ca8ace7b7c0a70a5b5f8f83e6dbccdf",
"assets/assets/images/logo.png": "8b5adabc5fc06ff91a3ecb073a7285b1",
"assets/assets/images/page1.jpg": "1c102542883f73ab117c8807d788c03c",
"assets/assets/images/page2.jpg": "bd93481bf2b0ee73e0e9ba2a308140a2",
"assets/assets/images/page3.jpg": "930d6454166ff99d664973cad83b8244",
"assets/FontManifest.json": "dc3d03800ccca4601324923c0b1d6d57",
"assets/fonts/MaterialIcons-Regular.otf": "9dd1ecd2ca90a11de704867c11eb6d47",
"assets/NOTICES": "ff6e48d55ff634ef9400080bf0622f8b",
"assets/packages/cupertino_icons/assets/CupertinoIcons.ttf": "33b7d9392238c04c131b6ce224e13711",
"assets/shaders/ink_sparkle.frag": "ecc85a2e95f5e9f53123dcaf8cb9b6ce",
"canvaskit/canvaskit.js": "140ccb7d34d0a55065fbd422b843add6",
"canvaskit/canvaskit.js.symbols": "58832fbed59e00d2190aa295c4d70360",
"canvaskit/canvaskit.wasm": "07b9f5853202304d3b0749d9306573cc",
"canvaskit/chromium/canvaskit.js": "5e27aae346eee469027c80af0751d53d",
"canvaskit/chromium/canvaskit.js.symbols": "193deaca1a1424049326d4a91ad1d88d",
"canvaskit/chromium/canvaskit.wasm": "24c77e750a7fa6d474198905249ff506",
"canvaskit/skwasm.js": "1ef3ea3a0fec4569e5d531da25f34095",
"canvaskit/skwasm.js.symbols": "0088242d10d7e7d6d2649d1fe1bda7c1",
"canvaskit/skwasm.wasm": "264db41426307cfc7fa44b95a7772109",
"canvaskit/skwasm_heavy.js": "413f5b2b2d9345f37de148e2544f584f",
"canvaskit/skwasm_heavy.js.symbols": "3c01ec03b5de6d62c34e17014d1decd3",
"canvaskit/skwasm_heavy.wasm": "8034ad26ba2485dab2fd49bdd786837b",
"favicon.png": "5dcef449791fa27946b3d35ad8803796",
"flutter.js": "888483df48293866f9f41d3d9274a779",
"flutter_bootstrap.js": "6ad96d1635699498c6dcc27b48dbe367",
"icons/Icon-192.png": "ac9a721a12bbc803b44f645561ecb1e1",
"icons/Icon-512.png": "96e752610906ba2a93c65f8abe1645f1",
"icons/Icon-maskable-192.png": "c457ef57daa1d16f64b27b786ec2ea3c",
"icons/Icon-maskable-512.png": "301a7604d45b3e739efc881eb04896ea",
"index.html": "f9c0d6f0f5a964ae4c8373849ec80f0d",
"/": "f9c0d6f0f5a964ae4c8373849ec80f0d",
"main.dart.js": "3bb5b0bf12d38a42e391d68aedb5407f",
"manifest.json": "79d16898f9f0efd1fbb42cfb64d3bbdb",
"version.json": "080fd128c941e72e51ed4c45e3ebf3cc"};
// The application shell files that are downloaded before a service worker can
// start.
const CORE = ["main.dart.js",
"index.html",
"flutter_bootstrap.js",
"assets/AssetManifest.bin.json",
"assets/FontManifest.json"];

// During install, the TEMP cache is populated with the application shell files.
self.addEventListener("install", (event) => {
  self.skipWaiting();
  return event.waitUntil(
    caches.open(TEMP).then((cache) => {
      return cache.addAll(
        CORE.map((value) => new Request(value, {'cache': 'reload'})));
    })
  );
});
// During activate, the cache is populated with the temp files downloaded in
// install. If this service worker is upgrading from one with a saved
// MANIFEST, then use this to retain unchanged resource files.
self.addEventListener("activate", function(event) {
  return event.waitUntil(async function() {
    try {
      var contentCache = await caches.open(CACHE_NAME);
      var tempCache = await caches.open(TEMP);
      var manifestCache = await caches.open(MANIFEST);
      var manifest = await manifestCache.match('manifest');
      // When there is no prior manifest, clear the entire cache.
      if (!manifest) {
        await caches.delete(CACHE_NAME);
        contentCache = await caches.open(CACHE_NAME);
        for (var request of await tempCache.keys()) {
          var response = await tempCache.match(request);
          await contentCache.put(request, response);
        }
        await caches.delete(TEMP);
        // Save the manifest to make future upgrades efficient.
        await manifestCache.put('manifest', new Response(JSON.stringify(RESOURCES)));
        // Claim client to enable caching on first launch
        self.clients.claim();
        return;
      }
      var oldManifest = await manifest.json();
      var origin = self.location.origin;
      for (var request of await contentCache.keys()) {
        var key = request.url.substring(origin.length + 1);
        if (key == "") {
          key = "/";
        }
        // If a resource from the old manifest is not in the new cache, or if
        // the MD5 sum has changed, delete it. Otherwise the resource is left
        // in the cache and can be reused by the new service worker.
        if (!RESOURCES[key] || RESOURCES[key] != oldManifest[key]) {
          await contentCache.delete(request);
        }
      }
      // Populate the cache with the app shell TEMP files, potentially overwriting
      // cache files preserved above.
      for (var request of await tempCache.keys()) {
        var response = await tempCache.match(request);
        await contentCache.put(request, response);
      }
      await caches.delete(TEMP);
      // Save the manifest to make future upgrades efficient.
      await manifestCache.put('manifest', new Response(JSON.stringify(RESOURCES)));
      // Claim client to enable caching on first launch
      self.clients.claim();
      return;
    } catch (err) {
      // On an unhandled exception the state of the cache cannot be guaranteed.
      console.error('Failed to upgrade service worker: ' + err);
      await caches.delete(CACHE_NAME);
      await caches.delete(TEMP);
      await caches.delete(MANIFEST);
    }
  }());
});
// The fetch handler redirects requests for RESOURCE files to the service
// worker cache.
self.addEventListener("fetch", (event) => {
  if (event.request.method !== 'GET') {
    return;
  }
  var origin = self.location.origin;
  var key = event.request.url.substring(origin.length + 1);
  // Redirect URLs to the index.html
  if (key.indexOf('?v=') != -1) {
    key = key.split('?v=')[0];
  }
  if (event.request.url == origin || event.request.url.startsWith(origin + '/#') || key == '') {
    key = '/';
  }
  // If the URL is not the RESOURCE list then return to signal that the
  // browser should take over.
  if (!RESOURCES[key]) {
    return;
  }
  // If the URL is the index.html, perform an online-first request.
  if (key == '/') {
    return onlineFirst(event);
  }
  event.respondWith(caches.open(CACHE_NAME)
    .then((cache) =>  {
      return cache.match(event.request).then((response) => {
        // Either respond with the cached resource, or perform a fetch and
        // lazily populate the cache only if the resource was successfully fetched.
        return response || fetch(event.request).then((response) => {
          if (response && Boolean(response.ok)) {
            cache.put(event.request, response.clone());
          }
          return response;
        });
      })
    })
  );
});
self.addEventListener('message', (event) => {
  // SkipWaiting can be used to immediately activate a waiting service worker.
  // This will also require a page refresh triggered by the main worker.
  if (event.data === 'skipWaiting') {
    self.skipWaiting();
    return;
  }
  if (event.data === 'downloadOffline') {
    downloadOffline();
    return;
  }
});
// Download offline will check the RESOURCES for all files not in the cache
// and populate them.
async function downloadOffline() {
  var resources = [];
  var contentCache = await caches.open(CACHE_NAME);
  var currentContent = {};
  for (var request of await contentCache.keys()) {
    var key = request.url.substring(origin.length + 1);
    if (key == "") {
      key = "/";
    }
    currentContent[key] = true;
  }
  for (var resourceKey of Object.keys(RESOURCES)) {
    if (!currentContent[resourceKey]) {
      resources.push(resourceKey);
    }
  }
  return contentCache.addAll(resources);
}
// Attempt to download the resource online before falling back to
// the offline cache.
function onlineFirst(event) {
  return event.respondWith(
    fetch(event.request).then((response) => {
      return caches.open(CACHE_NAME).then((cache) => {
        cache.put(event.request, response.clone());
        return response;
      });
    }).catch((error) => {
      return caches.open(CACHE_NAME).then((cache) => {
        return cache.match(event.request).then((response) => {
          if (response != null) {
            return response;
          }
          throw error;
        });
      });
    })
  );
}
