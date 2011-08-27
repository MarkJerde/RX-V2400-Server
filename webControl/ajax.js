
function doit() {
document.all.systemPower.setAttribute("toggled", "On" == "On");
};

function ajaxpoll()
{
	var req = new XMLHttpRequest();
	req.open("GET", "ajax.xml", true);
	req.onreadystatechange = function()
	{
		if (req.readyState != 4)  { return; }
		if (req.status != 200) { return; }

		var xml=req.responseXML;
		var val;
		var elm;

		val = xml.getElementsByTagName("InputVaux")[0].getElementsByTagName("Value")[0].firstChild.nodeValue;
		document.all.zone1vaux.firstChild.nodeValue = val;
		document.all.zone2vaux.firstChild.nodeValue = val;
		document.all.zone3vaux.firstChild.nodeValue = val;

		val = xml.getElementsByTagName("InputDvrVcr2")[0].getElementsByTagName("Value")[0].firstChild.nodeValue;
		document.all.zone1dvrvcr2.firstChild.nodeValue = val;
		document.all.zone2dvrvcr2.firstChild.nodeValue = val;
		document.all.zone3dvrvcr2.firstChild.nodeValue = val;

		val = xml.getElementsByTagName("InputVcr1")[0].getElementsByTagName("Value")[0].firstChild.nodeValue;
		document.all.zone1vcr1.firstChild.nodeValue = val;
		document.all.zone2vcr1.firstChild.nodeValue = val;
		document.all.zone3vcr1.firstChild.nodeValue = val;

		val = xml.getElementsByTagName("InputCblSat")[0].getElementsByTagName("Value")[0].firstChild.nodeValue;
		document.all.zone1cblsat.firstChild.nodeValue = val;
		document.all.zone2cblsat.firstChild.nodeValue = val;
		document.all.zone3cblsat.firstChild.nodeValue = val;

		val = xml.getElementsByTagName("InputDTV")[0].getElementsByTagName("Value")[0].firstChild.nodeValue;
		document.all.zone1dtv.firstChild.nodeValue = val;
		document.all.zone2dtv.firstChild.nodeValue = val;
		document.all.zone3dtv.firstChild.nodeValue = val;

		val = xml.getElementsByTagName("InputDVD")[0].getElementsByTagName("Value")[0].firstChild.nodeValue;
		document.all.zone1dvd.firstChild.nodeValue = val;
		document.all.zone2dvd.firstChild.nodeValue = val;
		document.all.zone3dvd.firstChild.nodeValue = val;

		val = xml.getElementsByTagName("InputMdtape")[0].getElementsByTagName("Value")[0].firstChild.nodeValue;
		document.all.zone1mdtape.firstChild.nodeValue = val;
		document.all.zone2mdtape.firstChild.nodeValue = val;
		document.all.zone3mdtape.firstChild.nodeValue = val;

		val = xml.getElementsByTagName("InputCDR")[0].getElementsByTagName("Value")[0].firstChild.nodeValue;
		document.all.zone1cdr.firstChild.nodeValue = val;
		document.all.zone2cdr.firstChild.nodeValue = val;
		document.all.zone3cdr.firstChild.nodeValue = val;

		val = xml.getElementsByTagName("InputCD")[0].getElementsByTagName("Value")[0].firstChild.nodeValue;
		document.all.zone1cd.firstChild.nodeValue = val;
		document.all.zone2cd.firstChild.nodeValue = val;
		document.all.zone3cd.firstChild.nodeValue = val;

		val = xml.getElementsByTagName("InputTuner")[0].getElementsByTagName("Value")[0].firstChild.nodeValue;
		document.all.zone1tuner.firstChild.nodeValue = val;
		document.all.zone2tuner.firstChild.nodeValue = val;
		document.all.zone3tuner.firstChild.nodeValue = val;

		val = xml.getElementsByTagName("InputPhono")[0].getElementsByTagName("Value")[0].firstChild.nodeValue;
		document.all.zone1phono.firstChild.nodeValue = val;
		document.all.zone2phono.firstChild.nodeValue = val;
		document.all.zone3phono.firstChild.nodeValue = val;

		val = xml.getElementsByTagName("SystemPower")[0].getElementsByTagName("Value")[0].firstChild.nodeValue;
		elm = document.all.systemPower;
		elm.setAttribute("toggled", "On" == val);

		val = xml.getElementsByTagName("Zone1Power")[0].getElementsByTagName("Value")[0].firstChild.nodeValue;
		elm = document.all.z1menuStatus;
		elm.innerHTML = val;
		elm = document.all.Zone1Power;
		elm.setAttribute("toggled", "On" == val);

		val = xml.getElementsByTagName("Zone1Volume")[0].getElementsByTagName("Value")[0].firstChild.nodeValue;
		elm = document.all.Zone1Volume;
		elm.value = val;

		val = xml.getElementsByTagName("Zone2Power")[0].getElementsByTagName("Value")[0].firstChild.nodeValue;
		elm = document.all.z2menuStatus;
		elm.innerHTML = val;
		elm = document.all.Zone2Power;
		elm.setAttribute("toggled", "On" == val);

		val = xml.getElementsByTagName("Zone2Volume")[0].getElementsByTagName("Value")[0].firstChild.nodeValue;
		elm = document.all.Zone2Volume;
		elm.value = val;

		val = xml.getElementsByTagName("Zone3Power")[0].getElementsByTagName("Value")[0].firstChild.nodeValue;
		elm = document.all.z3menuStatus;
		elm.innerHTML = val;
		elm = document.all.Zone3Power;
		elm.setAttribute("toggled", "On" == val);

		val = xml.getElementsByTagName("Zone3Volume")[0].getElementsByTagName("Value")[0].firstChild.nodeValue;
		elm = document.all.Zone3Volume;
		elm.value = val;
	};
	req.send();
};

(function() {

setInterval ( "ajaxpoll()", 5000 );

//alert("ajax loaded");
//setInterval ( "doit()", 1000 );

// Set expoential timeouts to load data ASAP then let the interval take over.
setTimeout ( "ajaxpoll()", 100 );
setTimeout ( "ajaxpoll()", 200 );
setTimeout ( "ajaxpoll()", 400 );
setTimeout ( "ajaxpoll()", 800 );
setTimeout ( "ajaxpoll()", 1600 );
setTimeout ( "ajaxpoll()", 3200 );

})();

