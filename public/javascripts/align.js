var dest_image;
function init() {
    mds = new OpenLayers.Control.MouseDefaults();
    mds.defaultDblClick = function() {
        return true;
    };

    from_map = new OpenLayers.Map('from_map',  
    { controls: [mds, new OpenLayers.Control.PanZoomBar()],
    maxExtent: new OpenLayers.Bounds(0,0,image_width, image_height),
   maxResolution: 'auto', numZoomLevels: 8});

var image = new OpenLayers.Layer.WMS( title, 
                    wms_url, { format: 'image/png', status: 'unwarped' } );
         
            from_map.addLayer(image);
 if (!from_map.getCenter()) from_map.zoomToMaxExtent();


 
    to_map = new OpenLayers.Map('to_map',  
    { controls: [mds, new OpenLayers.Control.PanZoomBar()],
    maxExtent: new OpenLayers.Bounds(0,0,image_width, image_height),
   maxResolution: 'auto', numZoomLevels: 8});

 dest_image = new OpenLayers.Layer.WMS('dst', 
                    wms_url, {layers: 'basic', format: 'image/png', status: 'unwarped' } );
         
            to_map.addLayer(dest_image);
 if (!to_map.getCenter()) to_map.zoomToMaxExtent();

}

function addLayerToDest(){
//  console.log("add");
  to_map.removeLayer(dest_image);
  frm = document.getElementById('layform');
  num =frm.layer_num.value;
  new_wms_url = empty_wms_url+'/'+num;
//console.log(new_wms_url);

  align_form = document.getElementById('align_form');
  align_form.destmap.value = num;
  var thing = (align_form.destmap.value);
 dest_image = new OpenLayers.Layer.WMS( "warped map", 
       new_wms_url, {layers: 'basic', format: 'image/png', status: 'unwarped' } );
   to_map.addLayer(dest_image);
  to_map.zoomToMaxExtent();
  // to_map.removeLayer('dst');

return false;
}

function checkSubmit(){
 
  frm = document.getElementById('align_form');
if ((frm.destmap.value != frm.srcmap.value) && (frm.destmap.value.length > 0)){
  return true;
}else {
  alert("either no map is loaded to be aligned, or the same map number was entered");
  return false;
}

}

