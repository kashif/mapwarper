	 var map;
	 var wmslayer;
	 var maxOpacity = 1;
   var minOpacity = 0.1;



   function init(){

   OpenLayers.IMAGE_RELOAD_ATTEMPTS = 3;
   OpenLayers.Util.onImageLoadErrorColor = "transparent";

    var options = {
        projection: new OpenLayers.Projection("EPSG:900913"),
        displayProjection: new OpenLayers.Projection("EPSG:4326"),
        units: "m",
        numZoomLevels:18,
        maxResolution: 156543.0339,
        maxExtent: new OpenLayers.Bounds(-20037508, -20037508,
            20037508, 20037508.34),
        controls: [
        new OpenLayers.Control.Attribution(),
        new OpenLayers.Control.LayerSwitcher(),
        new OpenLayers.Control.Navigation(),
        new OpenLayers.Control.PanZoomBar(),
        new OpenLayers.Control.MousePosition()
        ]
    };

   map = new OpenLayers.Map('map', options);
   // create OSM layer



   map.addLayer(mapnik);

   map.addLayer(osma);


   oamlayer.setVisibility(false);
   map.addLayer(oamlayer );


   var warped_wms_url = wms_url;

   wmslayer =  new OpenLayers.Layer.WMS
   ( "warped image",
   warped_wms_url,
   {format: 'image/png', status: 'warped'   },
   {         TRANSPARENT:'true', reproject: 'true'},
   { gutter: 15, buffer:0},
   { projection:"epsg:4326", units: "m"  }
   );
   var opacity = .7;
   wmslayer.setOpacity(opacity);
   wmslayer.setIsBaseLayer(false);
   map.addLayer(wmslayer);


   map.addLayer(jpl_wms);


   map_bounds_merc  = new OpenLayers.Bounds();

   map_bounds_merc  = lonLatToMercatorBounds(bounds);

   map.zoomToExtent(map_bounds_merc);

  //set up slider
  $("#slider").slider({
    startValue: 100 * opacity,
    slide: function(e, ui) {
    wmslayer.setOpacity(ui.value / 100);
    OpenLayers.Util.getElement('opacity').value = ui.value;
      }
      });


}

  function changeOpacity(byOpacity) {
            var newOpacity = (parseFloat(OpenLayers.Util.getElement('opacity').value) + byOpacity).toFixed(1);
            newOpacity = Math.min(maxOpacity,
                                  Math.max(minOpacity, newOpacity));
            OpenLayers.Util.getElement('opacity').value = newOpacity;
            wmslayer.setOpacity(newOpacity);
        }



function mercatorToLonLat(merc) {
	 var lon = (merc.lon / 20037508.34) * 180;
	 var lat = (merc.lat / 20037508.34) * 180;

	 lat = 180/Math.PI * (2 * Math.atan(Math.exp(lat * Math.PI / 180)) - Math.PI / 2);

 return new OpenLayers.LonLat(lon, lat);
}

function lonLatToMercator(ll) {
	 var lon = ll.lon * 20037508.34 / 180;
	 var lat = Math.log(Math.tan((90 + ll.lat) * Math.PI / 360)) / (Math.PI / 180);

	 lat = lat * 20037508.34 / 180;

	 return new OpenLayers.LonLat(lon, lat);
}

function lonLatToMercatorBounds(llbounds){
var proj = new OpenLayers.Projection("EPSG:4326");
var newbounds = llbounds.transform(proj, map.getProjectionObject());

return newbounds;

} 