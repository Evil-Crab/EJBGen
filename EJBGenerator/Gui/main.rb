require 'nokogiri'
require 'fileutils'

def generateButton__clicked(*argv)
  filePath = 'D:\Projects\EJBGenerator\DataStorage.npnets'
outPath = filePath.slice(0..filePath.rindex('\\')) + 'output'

if(!File.directory?(outPath))
  FileUtils.mkdir_p outPath
end


f = File.open(filePath)
doc = Nokogiri::XML(f)
f.close

doc =  doc.xpath('npnets:PetriNetNestedMarked')
systemNet = doc.xpath('child::net')[0]
elementNets = systemNet.xpath('//typeElementNet')

package = systemNet.xpath('netSystem')[0]['name'].gsub(' ', '_')

systemPlaces = systemNet.xpath('netSystem/places')

(0..systemPlaces.count-1).each do |i|
  placeName = systemPlaces[i]['name']
	arcsIds = systemPlaces[i]['outArcs'].delete('#').split

  placeType = systemPlaces[i]['type'].delete('#')

	transitionsNames = []
  (0..arcsIds.count-1).each do |i|
    transitionsId = systemNet.xpath("netSystem/arcsPT[@id='#{arcsIds[i]}']/@outTransition").to_s.delete('#')
    transitionsNames.push(systemNet.xpath("netSystem/transitions[@id='#{transitionsId}']/@name").to_s)
  end

  transitionsBlock = ''
  notifyBlock = ''
  (0..transitionsNames.count-1).each do |i|
    transitionsBlock << "@EJB\n#{transitionsNames[i]}Bean #{transitionsNames[i]};\n"
    notifyBlock << "#{transitionsNames[i]}.reciveNotification(name, true);\n"
  end

  createVarBlock = ""
  createBlock =""
  if(systemNet.xpath("typeAtomic[@id='#{placeType}']").count == 1)
    createVarBlock = "String type = \"black\";
    Integer idCounter = 0;"
    createBlock="public void createToken() {
        idCounter++;
        list.add(type + \"_\" + name + \"_\" + idCounter);
        notifyTransitions();
    }"
  end


  placeBean = "package #{package};

import java.util.ArrayList;
import java.util.List;
import javax.annotation.PostConstruct;
import javax.ejb.EJB;

import javax.ejb.Singleton;
import javax.ejb.Startup;


@Startup
@Singleton
public class #{placeName}Bean {


    #{transitionsBlock}

    List<String> list = new ArrayList<String>();
    String name = \"#{placeName}\";

    #{createVarBlock}

    String blocked = \"\";

    @PostConstruct
    void init() {
    }

    public void notifyTransitions() {
        if(!list.isEmpty())
        {
            #{notifyBlock}
        } else
        {
            #{notifyBlock.gsub('true', 'false')}
        }
    }

    public Boolean blockPosition(String name) {
        if((blocked.equals(\"\") || blocked.equals(name)) && (!list.isEmpty()))
        {
            blocked = name;
            return true;
        }

        return false;
    }

    public void unblockPosition(String name) {
        if(blocked.equals(name) || blocked.equals(\"\"))
        {
            blocked = \"\";
            notifyTransitions();
        }
    }

    public String getFirstToken() {
        return list.get(0);
    }

    public List<String> getTokens() {
        return list;
    }

    public void removeToken(String id) {
        list.remove(list.indexOf(id));
    }

    public void addToken(String id) {
        list.add(id);
        if(blocked.equals(\"\"))
            notifyTransitions();
    }

    #{createBlock}

}
"
  File.open("#{outPath}\\#{placeName}Bean.java", 'w') do |f|
    f.puts placeBean
  end


end

systemTransitions = systemNet.xpath('netSystem/transitions')

(0..systemTransitions.count-1).each do |i|
  transName = systemTransitions[i]['name']
  arcsPTIds = systemTransitions[i]['inArcs'].delete('#').split
  arcsTPIds = systemTransitions[i]['outArcs'].delete('#').split

  synch = {}
  if(!systemTransitions[i]['synchronization'].nil?)
    synchId = systemTransitions[i]['synchronization'].delete('#').split
    synchName = elementNets.xpath("net/transitions[@synchronization='##{synchId[0]}']/@name").to_s
    synchType = elementNets.xpath("net/transitions[@synchronization='##{synchId[0]}']/ancestor::typeElementNet/@id").to_s
    synch.store(synchName, synchType)
  end

  inputVariables = {}
  inputTypes = {}
  (0..arcsPTIds.count-1).each do |i|
    placesId = systemNet.xpath("netSystem/arcsPT[@id='#{arcsPTIds[i]}']/@inPlace").to_s.delete('#')
    variableId = systemNet.xpath("netSystem/arcsPT[@id='#{arcsPTIds[i]}']/inscription/monoms/@variable").to_s.delete('#')
    inputName = systemNet.xpath("netSystem/places[@id='#{placesId}']/@name").to_s
    inputVariable = systemNet.xpath("netSystem/transitions/variables[@id='#{variableId}']/@name").to_s
    inputType = systemNet.xpath("netSystem/places[@id='#{placesId}']/@type").to_s
    inputVariables.store(inputName, inputVariable)
    inputTypes.store(inputName, inputType)
  end

  outputs = {}
  (0..arcsTPIds.count-1).each do |i|
    placesId = systemNet.xpath("netSystem/arcsTP[@id='#{arcsTPIds[i]}']/@outPlace").to_s.delete('#')
    variableId = systemNet.xpath("netSystem/arcsTP[@id='#{arcsTPIds[i]}']/inscription/monoms/@variable").to_s.delete('#')
    outputName = systemNet.xpath("netSystem/places[@id='#{placesId}']/@name").to_s
    outputVariable = systemNet.xpath("netSystem/transitions/variables[@id='#{variableId}']/@name").to_s
    outputs.store(outputName,outputVariable)
  end

  puts '================================================'
  puts transName
  puts inputVariables
  puts inputTypes
  puts outputs
  puts synch

  variablesBlock = ''
  variables = inputVariables.merge(outputs).merge(synch)
  (0..variables.count-1).each do |i|
    variablesBlock << "@EJB\n#{variables.keys[i]}Bean #{variables.keys[i]};\n"
  end

  inputsBlock = ''
  (0..inputVariables.count-1).each do |i|
    inputsBlock << "inputs.put(\"#{inputVariables.keys[i]}\", false);\n"
  end

  blockBlock = "blocked = blocked"
  (0..inputVariables.count-1).each do |i|
    blockBlock << " && #{inputVariables.keys[i]}.blockPosition(name)"
  end
  blockBlock << ";"

  unblockBlock = ""
  (0..inputVariables.count-1).each do |i|
    unblockBlock << "#{inputVariables.keys[i]}.unblockPosition(name);\n"
  end

  triggerBlock = ''
  if(synch.count == 0)
    triggerBlock << "String token;\n"

    blackInput = inputVariables.select {|k,v| v == 'b'}
    (0..blackInput.count-1).each do |i|
      triggerBlock << "token = #{blackInput.keys[i]}.getFirstToken();\n#{blackInput.keys[i]}.removeToken(token);\n"
    end

    blackOutput= outputs.select {|k,v| v == 'b'}
    (0..blackOutput.count-1).each do |i|
      triggerBlock << "#{blackOutput.keys[i]}.createToken();\n"
    end

    nonblackInput = inputVariables.select {|k,v| v != 'b'}
    (0..nonblackInput.count-1).each do |i|
      triggerBlock << "token = #{nonblackInput.keys[i]}.getFirstToken();\n#{nonblackInput.keys[i]}.removeToken(token);\n"

      nonblackOutput = outputs.select {|k,v| v == nonblackInput.values[i]}
      if(nonblackOutput.count == 0)
        netManagerType =  systemNet.xpath("netSystem/places[@name='#{nonblackOutput.keys[0]}']/@type").to_s.delete('#')
        netManager =  doc.xpath("typeElementNet[@id='#{netManagerType}']/@name")
        variablesBlock << "@EJB\n#{netManager[0]}ManagerBean #{netManager[0]}Manager;\n"
        triggerBlock << "#{netManager}Manager.removeToken(token);\n"
      elsif(nonblackOutput.count == 1)
        triggerBlock << "#{nonblackOutput.keys[0]}.addToken(token);\n"
      elsif(nonblackOutput.count > 1)
        netManagerType =  systemNet.xpath("netSystem/places[@name='#{nonblackOutput.keys[0]}']/@type").to_s.delete('#')
        netManager =  doc.xpath("typeElementNet[@id='#{netManagerType}']/@name")
        variablesBlock << "@EJB\n#{netManager[0]}ManagerBean #{netManager[0]}Manager;\n"
        triggerBlock << "#{nonblackOutput.keys[0]}.addToken(token);\n"
        (1..nonblackOutput.count-1).each do |i|
          triggerBlock << "token = #{netManager}Manager.cloneToken(token);\n"
          triggerBlock << "#{nonblackOutput.keys[i]}.addToken(token);\n"
        end
      end
    end

    triggerBlock = "#{triggerBlock}doExtraStuff();\nunblockInputs();\n"
  end



  transBean = "package #{package};

import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import javax.annotation.PostConstruct;
import javax.annotation.Resource;
import javax.ejb.EJB;
import javax.ejb.Singleton;
import javax.ejb.Startup;
import javax.ejb.Timeout;
import javax.ejb.Timer;
import javax.ejb.TimerService;


@Startup
@Singleton
public class #{transName}Bean {

    #{variablesBlock}

    @Resource
    TimerService timerService;
    long duration = 5;

    Map<String, Boolean> inputs = new HashMap<String, Boolean>();
    String name = \"#{transName}\";
    boolean inWork = false;
    boolean waiting4Check = false;


    @PostConstruct
    void init() {
        #{inputsBlock}
    }

    public void reciveNotification(String name, Boolean status) {
        inputs.put(name, status);
        checkInputs();
    }

    @Timeout
    public void timeout() {
        waiting4Check = false;
        checkInputs();
    }

    private void checkInputs()
    {
        if(inWork)
        {
            if (!waiting4Check) {
                Timer timer = timerService.createTimer(duration, null);
                waiting4Check = true;
            }
            return;
        }

        inWork = true;
        boolean inputsFull = true;
        List<Boolean> list =  new ArrayList<Boolean>(inputs.values());
        for(int i = 0; i < inputs.size(); i++)
        {
            inputsFull = inputsFull && list.get(i);
        }

        if(inputsFull)
        {
            triggerTransition();
        }

        inWork = false;
    }

    private void triggerTransition() {
        if (blockInputs() && checkExtra()) {

          #{triggerBlock}

        } else {
            if (!waiting4Check) {
                Timer timer = timerService.createTimer(duration, null);
                waiting4Check = true;
            }
        }
    }

    private boolean blockInputs() {
        boolean blocked = true;
        #{blockBlock}

        if (!blocked) {
            unblockInputs();
        }

        return blocked;
    }

    private void unblockInputs()
    {
        #{unblockBlock}
    }
    private boolean checkExtra() {
        return true;
    }

    private void doExtraStuff() {
    }

}"

  File.open("#{outPath}\\#{transName}Bean.java", 'w') do |f|
    f.puts transBean
  end


end







end


