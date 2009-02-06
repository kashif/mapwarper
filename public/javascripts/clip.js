var vectors, formats;
var controls;
var map;
var navigate;
var modify;
var polygon;
function updateFormats() {

	formats = {
		'out': {
			//wkt: new OpenLayers.Format.WKT(out_options),
			wkt: new OpenLayers.Format.WKT(),
			geojson: new OpenLayers.Format.GeoJSON(),
			georss: new OpenLayers.Format.GeoRSS(),
			gml: new OpenLayers.Format.GML(),
			kml: new OpenLayers.Format.KML()
		}
	};
}

function init() {

    var	mds = new OpenLayers.Control.MouseDefaults();
//	mds.defaultDblClick = function() {
//		return true;
//	};

        var iw = image_width + 1000;
        var ih = image_height + 500;
	map = new OpenLayers.Map('map', {
		controls: [mds, new OpenLayers.Control.PanZoomBar()],
		maxExtent: new OpenLayers.Bounds(-1000, 0, iw, ih),
		maxResolution: 'auto',
		numZoomLevels: 9
	});

var image = new OpenLayers.Layer.WMS( title, 
                    wms_url, { format: 'image/png', status: 'unwarped' } );

	map.addLayer(image);
	if (!map.getCenter()) {
          map.zoomToMaxExtent();
        }
//if theres a file load it
//else make a plain one

        if (gml_file_exists) {
       
  vectors = new OpenLayers.Layer.GML("GML",gml_url); 
	}else {
          //console.log ("else");
	vectors = new OpenLayers.Layer.Vector("Vector Layer");
        }
	map.addLayer(vectors);

	updateFormats();



	var modifyOptions = {
		onModificationStart: function(feature) {
			//  OpenLayers.Console.log("start modifying", feature.id);
		},
		onModification: function(feature) {
			// OpenLayers.Console.log("modified", feature.id);
		},
		onModificationEnd: function(feature) {
			//  OpenLayers.Console.log("end modifying", feature.id);
		},
		onDelete: function(feature) {
			//  OpenLayers.Console.log("delete", feature.id);
		},
               title: "Modify existing polygon",
              displayClass: "olControlModifyFeature"
	};

         modify = new OpenLayers.Control.ModifyFeature(vectors, modifyOptions);
         navigate = new OpenLayers.Control.Navigation({title: "Move around Map"});
        polygon =  new OpenLayers.Control.DrawFeature(vectors, OpenLayers.Handler.Polygon,
            {title: "Draw new polygon to mask",
displayClass: 'olControlDrawFeature'});


        var controlpanel = new OpenLayers.Control.Panel ( 
            {displayClass: 'olControlEditingToolbar'}
            );

        controlpanel.addControls([navigate, modify, polygon]);

        map.addControl(controlpanel);
        navigate.activate();
        
       
}

function destroyMask(){
  //console.log("clearing mask");
vectors.destroyFeatures();

}
function deselect(){
modify.deactivate();
polygon.deactivate();
}
//vectors.features[0].geometry.components[0].components[0].x
function serialize_features() {
        
	// var type = document.getElementById("formatType").value;
	var type = "gml";
	var str = formats['out']['gml'].write(vectors.features);

	
document.getElementById('output').value = str;
}


