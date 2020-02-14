package dev.snowdrop;

import org.eclipse.microprofile.config.inject.ConfigProperty;

import javax.enterprise.context.ApplicationScoped;

@ApplicationScoped
public class HelloService {

    @ConfigProperty(name = "greeting")
    public String greeting;

    public String politeMessage(String name) {
        return greeting + "," + name;
    }
}
